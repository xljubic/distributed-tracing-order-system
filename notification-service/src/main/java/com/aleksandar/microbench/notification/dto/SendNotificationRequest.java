package com.aleksandar.microbench.notification.dto;

public record SendNotificationRequest(
        Long orderId,
        String type,
        String channel,
        String recipient,
        String message) {
}
