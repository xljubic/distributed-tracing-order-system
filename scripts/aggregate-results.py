import csv
import json
import math
import re
import statistics
import sys
from pathlib import Path


MODELS = {"rest", "partial-grpc", "full-grpc", "async", "hybrid"}
SCENARIOS = {"baseline", "stress", "spike", "endurance", "edge"}
RAW_FIELDS = [
    "model", "scenario", "run", "avg_ms", "median_ms", "p90_ms", "p95_ms",
    "p99_ms", "max_ms", "req_per_sec", "error_rate", "checks_rate", "iterations"
]
AGGREGATED_FIELDS = [
    "model", "scenario", "runs", "mean_avg_ms", "std_avg_ms", "mean_p95_ms",
    "std_p95_ms", "mean_req_per_sec", "std_req_per_sec", "mean_error_rate", "mean_checks_rate"
]


def metric_value(metrics, metric_name, value_name):
    metric = metrics.get(metric_name, {})
    values = metric.get("values", metric)
    return values.get(value_name, "")


def parse_result(path):
    parts = path.parts
    model_index = next((index for index, part in enumerate(parts) if part in MODELS), None)
    if model_index is None or model_index + 2 >= len(parts):
        return None
    model = parts[model_index]
    scenario = parts[model_index + 1]
    match = re.fullmatch(r"run-(\d+)\.json", path.name)
    if scenario not in SCENARIOS or not match:
        return None
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    metrics = data.get("metrics", {})
    return {
        "model": model,
        "scenario": scenario,
        "run": int(match.group(1)),
        "avg_ms": metric_value(metrics, "http_req_duration", "avg"),
        "median_ms": metric_value(metrics, "http_req_duration", "med"),
        "p90_ms": metric_value(metrics, "http_req_duration", "p(90)"),
        "p95_ms": metric_value(metrics, "http_req_duration", "p(95)"),
        "p99_ms": metric_value(metrics, "http_req_duration", "p(99)"),
        "max_ms": metric_value(metrics, "http_req_duration", "max"),
        "req_per_sec": metric_value(metrics, "http_reqs", "rate"),
        "error_rate": metric_value(metrics, "http_req_failed", "value"),
        "checks_rate": metric_value(metrics, "checks", "value"),
        "iterations": metric_value(metrics, "iterations", "count"),
    }


def numeric(rows, field):
    return [float(row[field]) for row in rows if row[field] not in ("", None)]


def mean_or_blank(values):
    return statistics.mean(values) if values else ""


def std_or_blank(values):
    return statistics.stdev(values) if len(values) > 1 else ""


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/aggregate-results.py <results-folder>")
    root = Path(sys.argv[1]).resolve()
    if not root.is_dir():
        raise SystemExit(f"Results folder does not exist: {root}")

    rows = []
    for path in sorted(root.rglob("run-*.json")):
        try:
            row = parse_result(path)
            if row:
                rows.append(row)
        except (OSError, json.JSONDecodeError, TypeError, ValueError) as error:
            print(f"Skipping {path}: {error}", file=sys.stderr)

    if not rows:
        raise SystemExit("No run-XX.json result files found.")

    raw_path = root / "raw-results.csv"
    with raw_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=RAW_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    groups = {}
    for row in rows:
        groups.setdefault((row["model"], row["scenario"]), []).append(row)
    aggregated = []
    for (model, scenario), group in sorted(groups.items()):
        avg_values = numeric(group, "avg_ms")
        p95_values = numeric(group, "p95_ms")
        throughput_values = numeric(group, "req_per_sec")
        aggregated.append({
            "model": model,
            "scenario": scenario,
            "runs": len(group),
            "mean_avg_ms": mean_or_blank(avg_values),
            "std_avg_ms": std_or_blank(avg_values),
            "mean_p95_ms": mean_or_blank(p95_values),
            "std_p95_ms": std_or_blank(p95_values),
            "mean_req_per_sec": mean_or_blank(throughput_values),
            "std_req_per_sec": std_or_blank(throughput_values),
            "mean_error_rate": mean_or_blank(numeric(group, "error_rate")),
            "mean_checks_rate": mean_or_blank(numeric(group, "checks_rate")),
        })

    aggregated_path = root / "aggregated-results.csv"
    with aggregated_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=AGGREGATED_FIELDS)
        writer.writeheader()
        writer.writerows(aggregated)

    comparison_fields = ["scenario"] + [f"{model}_mean_p95_ms" for model in sorted(MODELS)]
    by_scenario = {scenario: {row["model"]: row["mean_p95_ms"] for row in aggregated if row["scenario"] == scenario} for scenario in SCENARIOS}
    comparison_path = root / "comparison.csv"
    with comparison_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=comparison_fields)
        writer.writeheader()
        for scenario in sorted(by_scenario):
            writer.writerow({"scenario": scenario, **{f"{model}_mean_p95_ms": by_scenario[scenario].get(model, "") for model in sorted(MODELS)}})

    print(f"Wrote {len(rows)} raw rows to {raw_path}")
    print(f"Wrote {len(aggregated)} aggregate rows to {aggregated_path}")
    print(f"Wrote comparison rows to {comparison_path}")


if __name__ == "__main__":
    main()