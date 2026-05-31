package com.aleksandar.microbench.notification.mapper;

import com.aleksandar.microbench.notification.domain.Notification;
import com.aleksandar.microbench.notification.dto.NotificationResponse;

public class NotificationMapper {
    private NotificationMapper() {
    }

    public static NotificationResponse toResponse(Notification notification) {
        return new NotificationResponse(
                notification.getId(),
                notification.getOrderId(),
                notification.getType().name(),
                notification.getChannel().name(),
                notification.getRecipient(),
                notification.getMessage(),
                notification.getStatus().name(),
                notification.getFailureReason(),
                notification.getCreatedAt(),
                notification.getSentAt());
    }
}
