package com.aleksandar.microbench.order.client;

import java.time.LocalDateTime;

public record NotificationResponse(
        Long id,
        Long orderId,
        String type,
        String channel,
        String recipient,
        String message,
        String status,
        String failureReason,
        LocalDateTime createdAt,
        LocalDateTime sentAt) {
}
