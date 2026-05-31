package com.aleksandar.microbench.order.dto;

import java.util.List;

public record CreateOrderRequest(List<CreateOrderItemRequest> items) {
}
