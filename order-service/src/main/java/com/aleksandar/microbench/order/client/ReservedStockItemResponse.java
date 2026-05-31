package com.aleksandar.microbench.order.client;

public record ReservedStockItemResponse(
        Long productId,
        Integer quantity,
        String status
    ) {

}
