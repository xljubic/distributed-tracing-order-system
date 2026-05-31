package com.aleksandar.microbench.inventory.dto;

public record ReservedStockItemResponse(
        Long productId,
        Integer quantity,
        String status) {
}
