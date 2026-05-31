package com.aleksandar.microbench.order.client;

import java.math.BigDecimal;

public record ProcessPaymentRequest(
        Long orderId,
        BigDecimal amount) {
}
