package com.aleksandar.microbench.order.client.rest;


import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import com.aleksandar.microbench.order.client.ProductClient;
import com.aleksandar.microbench.order.client.ProductResponse;

@Component
public class RestProductClient implements ProductClient {

    private final RestClient restClient;

    public RestProductClient(
            RestClient.Builder restClientBuilder,
            @Value("${services.product-service.url}") String productServiceUrl) {
        this.restClient = restClientBuilder
                .baseUrl(productServiceUrl)
                .build();
    }

    @Override
    public ProductResponse getProductById(Long productId) {
        return restClient
                .get()
                .uri("/api/products/{id}", productId)
                .retrieve()
                .body(ProductResponse.class);
    }

}
