package com.aleksandar.microbench.order.supplementary;

import java.math.BigDecimal;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component("literatureRestClient")
public class LiteratureRestClient implements LiteratureBenchmarkClient {

    private final RestClient restClient;

    public LiteratureRestClient(
            RestClient.Builder restClientBuilder,
            @Value("${services.product-service.url}") String productServiceUrl) {
        this.restClient = restClientBuilder.baseUrl(productServiceUrl).build();
    }

    @Override
    public LiteratureFlatProductResponse getFlat(String payloadSize) {
        ProductResponse response = restClient.get()
                .uri("/api/supplementary/literature/products/{id}/flat/{payloadSize}", 1, payloadSize)
                .retrieve().body(ProductResponse.class);
        return new LiteratureFlatProductResponse(
                response.id(), response.name(), response.category(), response.price(), response.payload());
    }

    @Override
    public LiteratureNestedProductResponse getNested(String payloadSize) {
        NestedProductResponse response = restClient.get()
                .uri("/api/supplementary/literature/products/{id}/nested/{payloadSize}", 1, payloadSize)
                .retrieve().body(NestedProductResponse.class);
        return new LiteratureNestedProductResponse(
                new LiteratureNestedProductResponse.Product(
                        response.product().id(), response.product().name(), response.product().category(),
                        response.product().price()),
                new LiteratureNestedProductResponse.Payload(
                        response.payload().size(), response.payload().data()));
    }

    private record ProductResponse(Long id, String name, String category, BigDecimal price, String payload) {
    }

    private record NestedProductResponse(Product product, Payload payload) {
        private record Product(Long id, String name, String category, BigDecimal price) {
        }

        private record Payload(String size, String data) {
        }
    }
}