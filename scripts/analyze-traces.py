import csv
import json
import math
import statistics
import sys
from pathlib import Path


TRACE_FIELDS = [
    "model",
    "scenario",
    "repetition",
    "attempt",
    "probe_seq",
    "trace_id",
    "root_span_id",
    "root_service",
    "root_operation",
    "root_parent_span_id",
    "root_parent_missing",
    "probe_http_status",
    "probe_duration_ms",
    "trace_duration_ms",
    "root_request_duration_ms",
    "trace_workflow_duration_ms",
    "span_count",
    "service_count",
    "error_span_count",
    "error_span_rate",
    "http_client_span_count",
    "http_server_span_count",
    "grpc_client_span_count",
    "grpc_server_span_count",
    "db_span_count",
    "kafka_send_span_count",
    "kafka_consume_span_count",
    "kafka_producer_span_count",
    "kafka_consumer_span_count",
    "post_response_span_count",
    "post_response_tail_ms",
    "async_after_response_span_count",
    "longest_span_service",
    "longest_span_operation",
    "longest_span_ms",
    "dominant_service",
    "dominant_service_total_ms",
]

SPAN_FIELDS = [
    "model",
    "scenario",
    "repetition",
    "probe_seq",
    "trace_id",
    "span_id",
    "operation",
    "service",
    "start_time_us",
    "duration_us",
    "duration_ms",
    "span_kind",
    "protocol",
    "status_code",
    "error",
    "parent_span_id",
    "parent_reference_type",
    "parent_missing",
    "reference_count",
    "references_json",
]

SERVICE_FIELDS = [
    "model",
    "scenario",
    "trace_id",
    "service",
    "span_count",
    "total_duration_ms",
    "mean_duration_ms",
    "p95_duration_ms",
]

MODEL_SCENARIO_FIELDS = [
    "model",
    "scenario",
    "trace_count",
    "mean_trace_duration_ms",
    "median_trace_duration_ms",
    "p95_trace_duration_ms",
    "std_trace_duration_ms",
    "min_trace_duration_ms",
    "max_trace_duration_ms",
    "mean_root_request_duration_ms",
    "median_root_request_duration_ms",
    "p95_root_request_duration_ms",
    "mean_span_count",
    "mean_service_count",
    "dominant_service",
    "mean_http_client_ms",
    "mean_grpc_client_ms",
    "mean_db_ms",
    "mean_kafka_send_ms",
    "mean_kafka_consume_ms",
    "async_after_response_span_count",
    "error_span_rate",
]

TRACE_VALIDATION_FIELDS = [
    "trace_id",
    "model",
    "scenario",
    "repetition",
    "attempt",
    "probe_seq",
    "topology_valid",
    "missing_expected_components",
    "unexpected_components",
]

DEPENDENCY_FIELDS = [
    "model",
    "scenario",
    "repetition",
    "attempt",
    "probe_seq",
    "trace_id",
    "synchronous_dependency_wait_ms",
    "post_response_tail_ms",
    "product_call_ms",
    "inventory_call_ms",
    "payment_call_ms",
    "notification_sync_call_ms",
    "kafka_produce_ms",
    "order_db_wait_ms",
    "critical_dependency_service",
    "critical_dependency_protocol",
    "critical_dependency_duration_ms",
    "kafka_consume_ms",
]

REPETITION_FIELDS = [
    "model",
    "scenario",
    "repetition",
    "trace_count",
    "mean_trace_duration_ms",
    "median_trace_duration_ms",
    "p95_trace_duration_ms",
]

REPRESENTATIVE_FIELDS = [
    "model",
    "scenario",
    "trace_id",
    "root_request_duration_ms",
    "selection_reason",
    "jaeger_url",
]

REQUIRED_REPRESENTATIVES = [
    ("rest", "baseline"),
    ("rest", "spike"),
    ("partial-grpc", "spike"),
    ("full-grpc", "stress"),
    ("async", "spike"),
    ("hybrid", "spike"),
]


def parse_bool(value):
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() == "true"


def to_float(value):
    if value is None or value == "":
        return None
    return float(value)


def mean(values):
    vals = [v for v in values if v is not None]
    if not vals:
        return None
    return statistics.mean(vals)


def median(values):
    vals = [v for v in values if v is not None]
    if not vals:
        return None
    return statistics.median(vals)


def stdev(values):
    vals = [v for v in values if v is not None]
    if len(vals) < 2:
        return None
    return statistics.stdev(vals)


def percentile(values, p):
    vals = sorted(v for v in values if v is not None)
    if not vals:
        return None
    if len(vals) == 1:
        return vals[0]
    rank = (len(vals) - 1) * p
    low = math.floor(rank)
    high = math.ceil(rank)
    if low == high:
        return vals[low]
    fraction = rank - low
    return vals[low] + (vals[high] - vals[low]) * fraction


def first_tag(tags, key):
    for tag in tags:
        if tag.get("key") == key:
            return tag.get("value")
    return None


def get_service(span, processes):
    process_id = span.get("processID")
    process = processes.get(process_id, {})
    return process.get("serviceName", "")


def classify_span(span, tags):
    operation = (span.get("operationName") or "").lower()
    span_kind = (first_tag(tags, "span.kind") or first_tag(tags, "otel.span_kind") or "").lower()
    rpc_system = (first_tag(tags, "rpc.system") or "").lower()
    db_system = (first_tag(tags, "db.system") or "").lower()
    messaging_system = (first_tag(tags, "messaging.system") or "").lower()
    messaging_op = (first_tag(tags, "messaging.operation") or "").lower()
    http_method = (first_tag(tags, "http.method") or "").lower()

    protocol = "other"
    if rpc_system == "grpc" or "grpc" in operation:
        protocol = "grpc"
    elif db_system:
        protocol = "db"
    elif messaging_system == "kafka" or "kafka" in operation:
        protocol = "kafka"
    elif "http" in operation or http_method:
        protocol = "http"
    elif span_kind in {"client", "server"}:
        if operation.startswith(("get", "post", "put", "patch", "delete", "head", "options")):
            protocol = "http"

    is_http_client = protocol == "http" and span_kind == "client"
    is_http_server = protocol == "http" and span_kind == "server"
    is_grpc_client = protocol == "grpc" and span_kind == "client"
    is_grpc_server = protocol == "grpc" and span_kind == "server"
    is_db = protocol == "db"

    is_kafka_send = protocol == "kafka" and (
        span_kind in {"producer", "client"} or messaging_op in {"send", "publish"}
    )
    is_kafka_consume = protocol == "kafka" and (
        span_kind in {"consumer", "server"} or messaging_op in {"process", "receive"}
    )

    return {
        "protocol": protocol,
        "span_kind": span_kind,
        "is_http_client": is_http_client,
        "is_http_server": is_http_server,
        "is_grpc_client": is_grpc_client,
        "is_grpc_server": is_grpc_server,
        "is_db": is_db,
        "is_kafka_send": is_kafka_send,
        "is_kafka_consume": is_kafka_consume,
    }


def get_parent_reference(span):
    references = span.get("references") or []
    for ref in references:
        ref_type = ref.get("refType", "")
        if ref_type in {"CHILD_OF", "FOLLOWS_FROM"}:
            return ref
    if references:
        return references[0]
    return None


def pick_application_root(spans, span_ids, processes):
    enriched = []
    for span in spans:
        tags = span.get("tags") or []
        service = get_service(span, processes)
        ref = get_parent_reference(span)
        parent_span_id = ref.get("spanID") if ref else None
        parent_missing = bool(parent_span_id and parent_span_id not in span_ids)
        cls = classify_span(span, tags)
        is_order_service = service.startswith("order-service")
        is_server = cls["span_kind"] == "server"

        enriched.append(
            {
                "span": span,
                "service": service,
                "is_order_service": is_order_service,
                "is_server": is_server,
                "parent_span_id": parent_span_id,
                "parent_missing": parent_missing,
                "start": int(span.get("startTime", 0)),
            }
        )

    # Primary rule from requirement: earliest order-service SERVER span whose
    # referenced parent span ID is not present in exported spans.
    candidates = [
        item
        for item in enriched
        if item["is_order_service"] and item["is_server"] and item["parent_missing"]
    ]
    if candidates:
        return min(candidates, key=lambda item: item["start"]) ["span"]

    # Fallbacks in descending specificity.
    candidates = [
        item
        for item in enriched
        if item["is_order_service"] and item["parent_missing"]
    ]
    if candidates:
        return min(candidates, key=lambda item: item["start"]) ["span"]

    candidates = [
        item
        for item in enriched
        if item["is_order_service"] and item["is_server"]
    ]
    if candidates:
        return min(candidates, key=lambda item: item["start"]) ["span"]

    return min(spans, key=lambda span: int(span.get("startTime", 0))) if spans else None


def load_manifest(manifest_path):
    rows = []
    with manifest_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            row["repetition"] = int(row["repetition"])
            row["attempt"] = int(row["attempt"]) if row.get("attempt") else 1
            row["probe_seq"] = int(row["probe_seq"])
            row["export_verified"] = parse_bool(row.get("export_verified"))
            row["duration_ms"] = to_float(row.get("duration_ms"))
            row["http_status"] = int(row["http_status"]) if row.get("http_status") else None
            rows.append(row)
    return rows


def write_csv(path, fields, rows):
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def analyze(session_dir):
    session_dir = Path(session_dir).resolve()
    manifest_path = session_dir / "probe-manifest.csv"
    if not manifest_path.is_file():
        raise SystemExit(f"Manifest not found: {manifest_path}")

    analysis_dir = session_dir / "analysis"
    analysis_dir.mkdir(parents=True, exist_ok=True)

    manifest_rows = load_manifest(manifest_path)
    trace_rows = []
    span_rows = []
    service_rows = []
    validation_rows = []
    dependency_rows = []

    found_trace_ids = set()

    for row in manifest_rows:
        if not row["export_verified"]:
            continue

        trace_id = row["trace_id"]
        trace_file = (
            session_dir
            / "raw"
            / row["model"]
            / row["scenario"]
            / f"{trace_id}.json"
        )
        if not trace_file.is_file():
            continue

        found_trace_ids.add(trace_id)
        with trace_file.open("r", encoding="utf-8-sig") as handle:
            trace = json.load(handle)

        spans = trace.get("spans") or []
        processes = trace.get("processes") or {}
        if not spans:
            continue

        span_ids = {span.get("spanID") for span in spans if span.get("spanID")}
        root = pick_application_root(spans, span_ids, processes)
        if not root:
            continue

        trace_start = min(int(span.get("startTime", 0)) for span in spans)
        trace_end = max(int(span.get("startTime", 0)) + int(span.get("duration", 0)) for span in spans)
        trace_duration_ms = (trace_end - trace_start) / 1000.0

        root_start = int(root.get("startTime", 0))
        root_duration_us = int(root.get("duration", 0))
        root_end = root_start + root_duration_us
        root_duration_ms = root_duration_us / 1000.0

        service_totals = {}
        error_count = 0

        http_client_count = 0
        http_server_count = 0
        grpc_client_count = 0
        grpc_server_count = 0
        db_count = 0
        kafka_send_count = 0
        kafka_consume_count = 0
        async_after_response_count = 0

        longest = None

        for span in spans:
            tags = span.get("tags") or []
            service = get_service(span, processes)
            service_totals.setdefault(service, 0.0)
            duration_us = int(span.get("duration", 0))
            duration_ms = duration_us / 1000.0
            service_totals[service] += duration_ms

            start_us = int(span.get("startTime", 0))
            end_us = start_us + duration_us
            if start_us > root_end:
                async_after_response_count += 1

            cls = classify_span(span, tags)
            if cls["is_http_client"]:
                http_client_count += 1
            if cls["is_http_server"]:
                http_server_count += 1
            if cls["is_grpc_client"]:
                grpc_client_count += 1
            if cls["is_grpc_server"]:
                grpc_server_count += 1
            if cls["is_db"]:
                db_count += 1
            if cls["is_kafka_send"]:
                kafka_send_count += 1
            if cls["is_kafka_consume"]:
                kafka_consume_count += 1

            status_code = first_tag(tags, "otel.status_code") or first_tag(tags, "http.status_code")
            error_tag = first_tag(tags, "error")
            is_error = False
            if str(error_tag).lower() == "true":
                is_error = True
            if str(status_code).upper() == "ERROR":
                is_error = True
            try:
                if int(str(status_code)) >= 400:
                    is_error = True
            except (TypeError, ValueError):
                pass
            if is_error:
                error_count += 1

            ref = get_parent_reference(span)
            parent_span_id = ref.get("spanID") if ref else ""
            parent_ref_type = ref.get("refType") if ref else ""
            parent_missing = bool(parent_span_id and parent_span_id not in span_ids)

            references = span.get("references") or []
            span_rows.append(
                {
                    "model": row["model"],
                    "scenario": row["scenario"],
                    "repetition": row["repetition"],
                    "probe_seq": row["probe_seq"],
                    "trace_id": trace_id,
                    "span_id": span.get("spanID", ""),
                    "operation": span.get("operationName", ""),
                    "service": service,
                    "start_time_us": start_us,
                    "duration_us": duration_us,
                    "duration_ms": round(duration_ms, 6),
                    "span_kind": cls["span_kind"],
                    "protocol": cls["protocol"],
                    "status_code": status_code or "",
                    "error": is_error,
                    "parent_span_id": parent_span_id,
                    "parent_reference_type": parent_ref_type,
                    "parent_missing": parent_missing,
                    "reference_count": len(references),
                    "references_json": json.dumps(references, separators=(",", ":")),
                }
            )

            if longest is None or duration_ms > longest["duration_ms"]:
                longest = {
                    "duration_ms": duration_ms,
                    "service": service,
                    "operation": span.get("operationName", ""),
                }

        # Build parent->children index once for dependency and topology derivation.
        children_by_parent = {}
        for s in spans:
            ref = get_parent_reference(s)
            pid = ref.get("spanID") if ref else None
            if pid:
                children_by_parent.setdefault(pid, []).append(s)

        service_count = len([s for s in service_totals.keys() if s])
        dominant_service = ""
        dominant_service_total_ms = None
        if service_totals:
            dominant_service, dominant_service_total_ms = max(service_totals.items(), key=lambda item: item[1])

        for service, total_ms in sorted(service_totals.items()):
            service_spans = [
                int(span.get("duration", 0)) / 1000.0
                for span in spans
                if get_service(span, processes) == service
            ]
            service_rows.append(
                {
                    "model": row["model"],
                    "scenario": row["scenario"],
                    "trace_id": trace_id,
                    "service": service,
                    "span_count": len(service_spans),
                    "total_duration_ms": round(total_ms, 6),
                    "mean_duration_ms": round(mean(service_spans), 6) if service_spans else "",
                    "p95_duration_ms": round(percentile(service_spans, 0.95), 6) if service_spans else "",
                }
            )

        root_tags = root.get("tags") or []
        root_ref = get_parent_reference(root)
        root_parent_span_id = root_ref.get("spanID") if root_ref else ""
        root_parent_missing = bool(root_parent_span_id and root_parent_span_id not in span_ids)

        trace_rows.append(
            {
                "model": row["model"],
                "scenario": row["scenario"],
                "repetition": row["repetition"],
                "attempt": row.get("attempt", 1),
                "probe_seq": row["probe_seq"],
                "trace_id": trace_id,
                "root_span_id": root.get("spanID", ""),
                "root_service": get_service(root, processes),
                "root_operation": root.get("operationName", ""),
                "root_parent_span_id": root_parent_span_id,
                "root_parent_missing": root_parent_missing,
                "probe_http_status": row["http_status"] if row["http_status"] is not None else "",
                "probe_duration_ms": round(row["duration_ms"], 6) if row["duration_ms"] is not None else "",
                "trace_duration_ms": round(trace_duration_ms, 6),
                "root_request_duration_ms": round(root_duration_ms, 6),
                "trace_workflow_duration_ms": round(trace_duration_ms, 6),
                "span_count": len(spans),
                "service_count": service_count,
                "error_span_count": error_count,
                "error_span_rate": round(error_count / len(spans), 6) if spans else "",
                "http_client_span_count": http_client_count,
                "http_server_span_count": http_server_count,
                "grpc_client_span_count": grpc_client_count,
                "grpc_server_span_count": grpc_server_count,
                "db_span_count": db_count,
                "kafka_send_span_count": kafka_send_count,
                "kafka_consume_span_count": kafka_consume_count,
                "kafka_producer_span_count": kafka_send_count,
                "kafka_consumer_span_count": kafka_consume_count,
                "async_after_response_span_count": async_after_response_count,
                "post_response_span_count": async_after_response_count,
                "post_response_tail_ms": round(max(0, (trace_end - root_end)) / 1000.0, 6),
                "longest_span_service": longest["service"] if longest else "",
                "longest_span_operation": longest["operation"] if longest else "",
                "longest_span_ms": round(longest["duration_ms"], 6) if longest else "",
                "dominant_service": dominant_service,
                "dominant_service_total_ms": round(dominant_service_total_ms, 6)
                if dominant_service_total_ms is not None
                else "",
            }
        )

        # Additional per-trace dependency & topology validation
        # Build span id map
        span_map = {s.get("spanID"): s for s in spans if s.get("spanID")}
        client_spans = []
        server_spans = []
        for s in spans:
            tags = s.get("tags") or []
            cls = classify_span(s, tags)
            if cls["is_http_client"] or cls["is_grpc_client"] or cls["is_kafka_send"]:
                client_spans.append((s, cls))
            if cls["is_http_server"] or cls["is_grpc_server"] or cls["is_kafka_consume"]:
                server_spans.append((s, cls))

        # Pair client -> server by references when possible
        dependency_intervals = []
        per_service_call_ms = {"product": 0.0, "inventory": 0.0, "payment": 0.0, "notification": 0.0}
        kafka_produce_ms = 0.0
        kafka_consume_ms = 0.0
        order_db_wait_ms = 0.0
        critical_dependency_service = ""
        critical_dependency_protocol = ""
        critical_dependency_duration_ms = 0.0

        for (cspan, ccls) in client_spans:
            cstart = int(cspan.get("startTime", 0))
            cend = cstart + int(cspan.get("duration", 0))
            child_servers = []
            for child in children_by_parent.get(cspan.get("spanID"), []):
                ctags = child.get("tags") or []
                ccls_child = classify_span(child, ctags)
                if ccls_child.get("is_http_server") or ccls_child.get("is_grpc_server") or ccls_child.get("is_kafka_consume"):
                    child_servers.append((child, ccls_child))

            if child_servers:
                for paired_server, _ in child_servers:
                    sservice = get_service(paired_server, processes)
                    sstart = int(paired_server.get("startTime", 0))
                    send = sstart + int(paired_server.get("duration", 0))
                    # interval from client start to server end (order-service waiting interval)
                    dependency_intervals.append((cstart, send))
                    # attribute server duration to service categories
                    dur_ms = int(paired_server.get("duration", 0)) / 1000.0
                    if "product-service" in sservice or sservice.startswith("product-") or "product" in sservice:
                        per_service_call_ms["product"] += dur_ms
                    if "inventory-service" in sservice or "inventory" in sservice:
                        per_service_call_ms["inventory"] += dur_ms
                    if "payment-service" in sservice or "payment" in sservice:
                        per_service_call_ms["payment"] += dur_ms
                    if "notification-service" in sservice or "notification" in sservice:
                        per_service_call_ms["notification"] += dur_ms

                    dep_dur_ms = (send - cstart) / 1000.0
                    protocol = ccls.get("protocol", "")
                    if dep_dur_ms > critical_dependency_duration_ms:
                        critical_dependency_duration_ms = dep_dur_ms
                        critical_dependency_service = sservice
                        critical_dependency_protocol = protocol
            else:
                # Kafka produce spans have no paired server in same trace
                if ccls.get("is_kafka_send"):
                    kafka_produce_ms += int(cspan.get("duration", 0)) / 1000.0

        # kafka consume totals
        for (sspan, scls) in server_spans:
            if scls.get("is_kafka_consume"):
                kafka_consume_ms += int(sspan.get("duration", 0)) / 1000.0

        # DB wait from order-service scoped db spans only.
        for s in spans:
            tags = s.get("tags") or []
            cls = classify_span(s, tags)
            svc = get_service(s, processes)
            if cls.get("is_db") and str(svc).startswith("order-service"):
                order_db_wait_ms += int(s.get("duration", 0)) / 1000.0

        # compute union length of dependency_intervals
        synchronous_wait_ms = 0.0
        if dependency_intervals:
            intervals = sorted(dependency_intervals, key=lambda x: x[0])
            merged = [intervals[0]]
            for st, en in intervals[1:]:
                last_st, last_en = merged[-1]
                if st <= last_en:
                    merged[-1] = (last_st, max(last_en, en))
                else:
                    merged.append((st, en))
            # intersect union with root window [root_start, root_end]
            root_win_st = root_start
            root_win_en = root_end
            total_us = 0
            for st, en in merged:
                ist = max(st, root_win_st)
                ien = min(en, root_win_en)
                if ien > ist:
                    total_us += (ien - ist)
            synchronous_wait_ms = total_us / 1000.0

        # post response tail: work after root_end
        tail_end = max(int(s.get("startTime", 0)) + int(s.get("duration", 0)) for s in spans)
        post_response_tail_ms = max(0, (tail_end - root_end)) / 1000.0

        dependency_rows.append(
            {
                "model": row["model"],
                "scenario": row["scenario"],
                "repetition": row["repetition"],
                "attempt": row.get("attempt", 1),
                "probe_seq": row["probe_seq"],
                "trace_id": trace_id,
                "synchronous_dependency_wait_ms": round(synchronous_wait_ms, 6),
                "post_response_tail_ms": round(post_response_tail_ms, 6),
                "product_call_ms": round(per_service_call_ms["product"], 6),
                "inventory_call_ms": round(per_service_call_ms["inventory"], 6),
                "payment_call_ms": round(per_service_call_ms["payment"], 6),
                "notification_sync_call_ms": round(per_service_call_ms["notification"], 6),
                "kafka_produce_ms": round(kafka_produce_ms, 6),
                "order_db_wait_ms": round(order_db_wait_ms, 6),
                "critical_dependency_service": critical_dependency_service,
                "critical_dependency_protocol": critical_dependency_protocol,
                "critical_dependency_duration_ms": round(critical_dependency_duration_ms, 6),
                "kafka_consume_ms": round(kafka_consume_ms, 6),
            }
        )

        # Topology validation
        expected = {
            "rest": {"product": "http", "inventory": "http", "payment": "http", "notification": "http"},
            "partial-grpc": {"product": "http", "inventory": "grpc", "payment": "http", "notification": "http"},
            "full-grpc": {"product": "grpc", "inventory": "grpc", "payment": "grpc", "notification": "grpc"},
            "async": {"product": "http", "inventory": "http", "payment": "http", "notification": "kafka"},
            "hybrid": {"product": "grpc", "inventory": "grpc", "payment": "grpc", "notification": "kafka"},
        }

        missing_expected = []
        unexpected = []
        # detect client->server protocol pairs
        detected = {}
        for (cspan, ccls) in client_spans:
            for child in children_by_parent.get(cspan.get("spanID"), []):
                sservice = get_service(child, processes)
                protocol = ccls.get("protocol")
                # normalize service short names
                short = None
                if "product" in sservice:
                    short = "product"
                elif "inventory" in sservice:
                    short = "inventory"
                elif "payment" in sservice:
                    short = "payment"
                elif "notification" in sservice:
                    short = "notification"
                if short:
                    detected.setdefault(short, set()).add(protocol)

        exp = expected.get(row["model"], {})
        for svc, proto in exp.items():
            seen = detected.get(svc, set())
            if proto == "kafka":
                # expect kafka produce from order-service and kafka consume in notification-service
                if not ("kafka" in seen):
                    missing_expected.append(f"{svc}:kafka")
            else:
                if proto not in seen:
                    missing_expected.append(f"{svc}:{proto}")

        # For async/hybrid, ensure no synchronous notification calls
        if row["model"] in {"async", "hybrid"}:
            if "http" in detected.get("notification", set()) or "grpc" in detected.get("notification", set()):
                unexpected.append("notification:http_or_grpc")

            # Explicit mandatory checks: producer and consumer visibility must both exist.
            if kafka_send_count <= 0:
                missing_expected.append("kafka:producer_span")
            if kafka_consume_count <= 0:
                missing_expected.append("kafka:consumer_span")

        validation_rows.append(
            {
                "trace_id": trace_id,
                "model": row["model"],
                "scenario": row["scenario"],
                "repetition": row["repetition"],
                "attempt": row.get("attempt", ""),
                "probe_seq": row["probe_seq"],
                "topology_valid": len(missing_expected) == 0 and len(unexpected) == 0,
                "missing_expected_components": ";".join(missing_expected),
                "unexpected_components": ";".join(unexpected),
            }
        )

    write_csv(analysis_dir / "trace-summary.csv", TRACE_FIELDS, trace_rows)
    write_csv(analysis_dir / "span-summary.csv", SPAN_FIELDS, span_rows)
    write_csv(analysis_dir / "service-summary.csv", SERVICE_FIELDS, service_rows)

    grouped = {}
    for row in trace_rows:
        key = (row["model"], row["scenario"])
        grouped.setdefault(key, []).append(row)

    model_scenario_rows = []
    for (model, scenario), rows in sorted(grouped.items()):
        trace_durations = [to_float(r["trace_duration_ms"]) for r in rows]
        root_durations = [to_float(r["root_request_duration_ms"]) for r in rows]
        span_counts = [to_float(r["span_count"]) for r in rows]
        service_counts = [to_float(r["service_count"]) for r in rows]

        dominant_service = ""
        service_totals = {}
        for r in rows:
            svc = r["dominant_service"]
            dur = to_float(r["dominant_service_total_ms"])
            if svc and dur is not None:
                service_totals.setdefault(svc, []).append(dur)
        if service_totals:
            dominant_service = max(service_totals.items(), key=lambda item: mean(item[1]))[0]

        http_client_ms = []
        grpc_client_ms = []
        db_ms = []
        kafka_send_ms = []
        kafka_consume_ms = []
        async_after_counts = []
        error_rates = []

        for r in rows:
            trace_id = r["trace_id"]
            these_spans = [
                s for s in span_rows if s["trace_id"] == trace_id and s["model"] == model and s["scenario"] == scenario
            ]

            http_client_ms.append(sum(to_float(s["duration_ms"]) for s in these_spans if s["protocol"] == "http" and s["span_kind"] == "client"))
            grpc_client_ms.append(sum(to_float(s["duration_ms"]) for s in these_spans if s["protocol"] == "grpc" and s["span_kind"] == "client"))
            db_ms.append(sum(to_float(s["duration_ms"]) for s in these_spans if s["protocol"] == "db"))
            kafka_send_ms.append(
                sum(
                    to_float(s["duration_ms"])
                    for s in these_spans
                    if s["protocol"] == "kafka" and s["span_kind"] in {"producer", "client"}
                )
            )
            kafka_consume_ms.append(
                sum(
                    to_float(s["duration_ms"])
                    for s in these_spans
                    if s["protocol"] == "kafka" and s["span_kind"] in {"consumer", "server"}
                )
            )
            async_after_counts.append(to_float(r["async_after_response_span_count"]))
            error_rates.append(to_float(r["error_span_rate"]))

        model_scenario_rows.append(
            {
                "model": model,
                "scenario": scenario,
                "trace_count": len(rows),
                "mean_trace_duration_ms": round(mean(trace_durations), 6) if mean(trace_durations) is not None else "",
                "median_trace_duration_ms": round(median(trace_durations), 6) if median(trace_durations) is not None else "",
                "p95_trace_duration_ms": round(percentile(trace_durations, 0.95), 6)
                if percentile(trace_durations, 0.95) is not None
                else "",
                "std_trace_duration_ms": round(stdev(trace_durations), 6) if stdev(trace_durations) is not None else "",
                "min_trace_duration_ms": round(min(trace_durations), 6) if trace_durations else "",
                "max_trace_duration_ms": round(max(trace_durations), 6) if trace_durations else "",
                "mean_root_request_duration_ms": round(mean(root_durations), 6)
                if mean(root_durations) is not None
                else "",
                "median_root_request_duration_ms": round(median(root_durations), 6)
                if median(root_durations) is not None
                else "",
                "p95_root_request_duration_ms": round(percentile(root_durations, 0.95), 6)
                if percentile(root_durations, 0.95) is not None
                else "",
                "mean_span_count": round(mean(span_counts), 6) if mean(span_counts) is not None else "",
                "mean_service_count": round(mean(service_counts), 6)
                if mean(service_counts) is not None
                else "",
                "dominant_service": dominant_service,
                "mean_http_client_ms": round(mean(http_client_ms), 6) if mean(http_client_ms) is not None else "",
                "mean_grpc_client_ms": round(mean(grpc_client_ms), 6) if mean(grpc_client_ms) is not None else "",
                "mean_db_ms": round(mean(db_ms), 6) if mean(db_ms) is not None else "",
                "mean_kafka_send_ms": round(mean(kafka_send_ms), 6)
                if mean(kafka_send_ms) is not None
                else "",
                "mean_kafka_consume_ms": round(mean(kafka_consume_ms), 6)
                if mean(kafka_consume_ms) is not None
                else "",
                "async_after_response_span_count": round(mean(async_after_counts), 6)
                if mean(async_after_counts) is not None
                else "",
                "error_span_rate": round(mean(error_rates), 6) if mean(error_rates) is not None else "",
            }
        )

    write_csv(analysis_dir / "model-scenario-summary.csv", MODEL_SCENARIO_FIELDS, model_scenario_rows)

    representative = []
    for (model, scenario), rows in sorted(grouped.items()):
        candidates = [r for r in rows if to_float(r.get("root_request_duration_ms")) is not None]
        if not candidates:
            continue
        root_durations = [to_float(r["root_request_duration_ms"]) for r in candidates]
        med = median(root_durations)
        chosen = min(candidates, key=lambda r: abs(to_float(r["root_request_duration_ms"]) - med))
        representative.append(
            {
                "model": model,
                "scenario": scenario,
                "trace_id": chosen["trace_id"],
                "root_request_duration_ms": chosen["root_request_duration_ms"],
                "selection_reason": "nearest-median-root_request_duration_ms",
                "jaeger_url": f"http://localhost:16686/trace/{chosen['trace_id']}",
            }
        )

    write_csv(analysis_dir / "representative-traces.csv", REPRESENTATIVE_FIELDS, representative)

    # Export representative trace JSONs for easy thesis evidence packaging.
    representative_dir = session_dir / "representative"
    representative_dir.mkdir(parents=True, exist_ok=True)
    for rep in representative:
        source = session_dir / "raw" / rep["model"] / rep["scenario"] / f"{rep['trace_id']}.json"
        target = representative_dir / f"{rep['model']}-{rep['scenario']}-{rep['trace_id']}.json"
        if source.is_file():
            target.write_text(source.read_text(encoding="utf-8-sig"), encoding="utf-8")

    # Write trace validation and dependency summaries
    write_csv(analysis_dir / "trace-validation.csv", TRACE_VALIDATION_FIELDS, validation_rows)
    write_csv(analysis_dir / "dependency-summary.csv", DEPENDENCY_FIELDS, dependency_rows)

    # Repetition-level summary
    rep_group = {}
    for r in trace_rows:
        key = (r["model"], r["scenario"], r["repetition"])
        rep_group.setdefault(key, []).append(r)

    rep_rows = []
    for (model, scenario, repetition), rows in sorted(rep_group.items()):
        durations = [to_float(r["trace_duration_ms"]) for r in rows]
        rep_rows.append(
            {
                "model": model,
                "scenario": scenario,
                "repetition": repetition,
                "trace_count": len(rows),
                "mean_trace_duration_ms": round(mean(durations), 6) if mean(durations) is not None else "",
                "median_trace_duration_ms": round(median(durations), 6) if median(durations) is not None else "",
                "p95_trace_duration_ms": round(percentile(durations, 0.95), 6) if percentile(durations, 0.95) is not None else "",
            }
        )

    write_csv(analysis_dir / "repetition-summary.csv", REPETITION_FIELDS, rep_rows)

    # Link historical external performance benchmark with internal tracing summaries.
    perf_csv = session_dir.parents[2] / "performance" / "2026-08-21_165935" / "aggregated-results.csv"
    linkage_rows = []
    if perf_csv.is_file():
        with perf_csv.open("r", encoding="utf-8-sig", newline="") as handle:
            perf_data = list(csv.DictReader(handle))

        trace_summary_by_combo = {
            (r["model"], r["scenario"]): r for r in model_scenario_rows
        }

        for prow in perf_data:
            scenario = (prow.get("scenario") or "").strip().lower()
            model = (prow.get("model") or "").strip().lower()
            if scenario not in {"baseline", "stress", "spike"}:
                continue
            tr = trace_summary_by_combo.get((model, scenario))
            linkage_rows.append(
                {
                    "model": model,
                    "scenario": scenario,
                    "historical_source": str(perf_csv),
                    "historical_raw_runs": prow.get("runs", ""),
                    "historical_mean_ms": prow.get("mean_avg_ms", ""),
                    "historical_p95_ms": prow.get("mean_p95_ms", ""),
                    "historical_error_rate": prow.get("mean_error_rate", ""),
                    "tracing_trace_count": tr.get("trace_count", "") if tr else "",
                    "tracing_mean_root_request_ms": tr.get("mean_root_request_duration_ms", "") if tr else "",
                    "tracing_p95_root_request_ms": tr.get("p95_root_request_duration_ms", "") if tr else "",
                    "tracing_mean_kafka_send_ms": tr.get("mean_kafka_send_ms", "") if tr else "",
                    "tracing_mean_kafka_consume_ms": tr.get("mean_kafka_consume_ms", "") if tr else "",
                }
            )

    if linkage_rows:
        linkage_fields = list(linkage_rows[0].keys())
        write_csv(analysis_dir / "performance-tracing-linkage.csv", linkage_fields, linkage_rows)
    else:
        write_csv(
            analysis_dir / "performance-tracing-linkage.csv",
            [
                "model",
                "scenario",
                "historical_source",
                "historical_raw_runs",
                "historical_mean_ms",
                "historical_p95_ms",
                "historical_error_rate",
                "tracing_trace_count",
                "tracing_mean_root_request_ms",
                "tracing_p95_root_request_ms",
                "tracing_mean_kafka_send_ms",
                "tracing_mean_kafka_consume_ms",
            ],
            [],
        )

    expected_verified = {
        row["trace_id"]
        for row in manifest_rows
        if row["export_verified"]
    }
    missing = sorted(expected_verified - found_trace_ids)

    print(f"Session: {session_dir}")
    print(f"Manifest rows: {len(manifest_rows)}")
    print(f"Verified traces in manifest: {len(expected_verified)}")
    print(f"Trace files analyzed: {len(trace_rows)}")
    if missing:
        print("Missing verified trace files:")
        for trace_id in missing:
            print(f"- {trace_id}")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/analyze-traces.py <results/tracing/final/<timestamp>>")
    analyze(sys.argv[1])


if __name__ == "__main__":
    main()
