package com.aleksandar.microbench.notification.event;

public record OrderCompletedEvent(
        Long orderId,
        String type,
        String channel,
        String recipient,
        String message) {
}
