package com.aleksandar.microbench.inventory.dto;

public record InventoryItemResponse(
        Long productId,
        Integer availableQuantity,
        Integer reservedQuantity) {
}
