package com.aleksandar.microbench.order.dto;


public record CreateOrderItemRequest(
        Long productId,
        Integer quantity
) {
}
