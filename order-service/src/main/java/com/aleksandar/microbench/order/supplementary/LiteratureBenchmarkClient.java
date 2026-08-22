package com.aleksandar.microbench.order.supplementary;

public interface LiteratureBenchmarkClient {
    LiteratureFlatProductResponse getFlat(String payloadSize);

    LiteratureNestedProductResponse getNested(String payloadSize);
}