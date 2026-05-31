package com.aleksandar.microbench.order.client;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record PaymentResponse(
        Long paymentId,
        Long orderId,
        String status,
        BigDecimal amount,
        String failureReason,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {
}
