package com.aleksandar.microbench.order.supplementary;

import java.util.Locale;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class LiteratureBenchmarkController {

    private final LiteratureBenchmarkClient restClient;
    private final LiteratureBenchmarkClient grpcClient;

    public LiteratureBenchmarkController(
            @Qualifier("literatureRestClient") LiteratureBenchmarkClient restClient,
            @Qualifier("literatureGrpcClient") LiteratureBenchmarkClient grpcClient) {
        this.restClient = restClient;
        this.grpcClient = grpcClient;
    }

    @GetMapping("/api/supplementary/literature/{transport}/{shape}/{payloadSize}")
    public Object getProduct(
            @PathVariable("transport") String transport,
            @PathVariable("shape") String shape,
            @PathVariable("payloadSize") String payloadSize) {
        LiteratureBenchmarkClient client = switch (transport.toLowerCase(Locale.ROOT)) {
            case "rest" -> restClient;
            case "grpc" -> grpcClient;
            default -> throw new IllegalArgumentException("Unsupported transport: " + transport);
        };
        return switch (shape.toLowerCase(Locale.ROOT)) {
            case "flat" -> client.getFlat(payloadSize);
            case "nested" -> client.getNested(payloadSize);
            default -> throw new IllegalArgumentException("Unsupported response shape: " + shape);
        };
    }
}