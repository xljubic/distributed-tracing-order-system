package com.aleksandar.microbench.order.client;

public record SendNotificationRequest(
        Long orderId,
        String type,
        String channel,
        String recipient,
        String message) {
}
