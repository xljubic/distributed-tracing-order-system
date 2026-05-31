package com.aleksandar.microbench.inventory.dto;

public record ReserveStockItemRequest(
        Long productId,
        Integer quantity) {
}
