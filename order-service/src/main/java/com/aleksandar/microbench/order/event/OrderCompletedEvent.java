package com.aleksandar.microbench.order.event;

public record OrderCompletedEvent(
        Long orderId,
        String type,
        String channel,
        String recipient,
        String message) {
}
