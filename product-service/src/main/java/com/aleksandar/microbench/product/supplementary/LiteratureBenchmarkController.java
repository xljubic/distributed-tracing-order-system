package com.aleksandar.microbench.product.supplementary;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class LiteratureBenchmarkController {

    private final LiteratureBenchmarkService benchmarkService;

    public LiteratureBenchmarkController(LiteratureBenchmarkService benchmarkService) {
        this.benchmarkService = benchmarkService;
    }

    @GetMapping("/api/supplementary/literature/products/{id}/flat/{payloadSize}")
    public LiteratureProductResponse getFlat(
            @PathVariable("id") Long id, @PathVariable("payloadSize") String payloadSize) {
        return benchmarkService.getFlat(id, LiteraturePayloadSize.parse(payloadSize));
    }

    @GetMapping("/api/supplementary/literature/products/{id}/nested/{payloadSize}")
    public LiteratureNestedProductResponse getNested(
            @PathVariable("id") Long id, @PathVariable("payloadSize") String payloadSize) {
        return benchmarkService.getNested(id, LiteraturePayloadSize.parse(payloadSize));
    }
}