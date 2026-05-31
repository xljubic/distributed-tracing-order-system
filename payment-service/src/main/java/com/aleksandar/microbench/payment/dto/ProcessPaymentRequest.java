package com.aleksandar.microbench.payment.dto;

import java.math.BigDecimal;

public record ProcessPaymentRequest(
        Long orderId,
        BigDecimal amount) {
}
