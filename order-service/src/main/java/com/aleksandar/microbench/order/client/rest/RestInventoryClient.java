package com.aleksandar.microbench.order.client.rest;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.aleksandar.microbench.order.client.InventoryClient;
import com.aleksandar.microbench.order.client.ReserveStockRequest;
import com.aleksandar.microbench.order.client.ReserveStockResponse;
import com.aleksandar.microbench.order.exception.InventoryReservationException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;

@ConditionalOnProperty(name = "communication.inventory", havingValue = "rest", matchIfMissing = true)
@Component
public class RestInventoryClient implements InventoryClient {
    private final RestClient restClient;

    public RestInventoryClient(
            RestClient.Builder restClientBuilder,
            @Value("${services.inventory-service.url}") String inventoryServiceUrl) {
        this.restClient = restClientBuilder
                .baseUrl(inventoryServiceUrl)
                .build();
    }

    @Override
    public ReserveStockResponse reserveStock(ReserveStockRequest request) {
        try {
            return restClient
                    .post()
                    .uri("/api/inventory/reservations")
                    .body(request)
                    .retrieve()
                    .body(ReserveStockResponse.class);
        } catch (RestClientException ex) {
            throw new InventoryReservationException("Inventory reservation failed");
        }
    }

}
