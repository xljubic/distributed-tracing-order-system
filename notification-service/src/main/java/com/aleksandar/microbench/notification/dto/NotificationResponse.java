package com.aleksandar.microbench.notification.dto;

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
