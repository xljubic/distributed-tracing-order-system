package com.aleksandar.microbench.order.client;

public record ReserveStockItemRequest(
        Long productId,
        Integer quantity) {

}
