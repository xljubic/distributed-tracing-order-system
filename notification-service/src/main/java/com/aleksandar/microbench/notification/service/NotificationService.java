package com.aleksandar.microbench.notification.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;

import com.aleksandar.microbench.notification.domain.Notification;
import com.aleksandar.microbench.notification.domain.NotificationChannel;
import com.aleksandar.microbench.notification.domain.NotificationStatus;
import com.aleksandar.microbench.notification.domain.NotificationType;
import com.aleksandar.microbench.notification.dto.NotificationResponse;
import com.aleksandar.microbench.notification.dto.SendNotificationRequest;
import com.aleksandar.microbench.notification.exception.InvalidNotificationRequestException;
import com.aleksandar.microbench.notification.exception.NotificationNotFoundException;
import com.aleksandar.microbench.notification.mapper.NotificationMapper;
import com.aleksandar.microbench.notification.repository.NotificationRepository;

@Service
public class NotificationService {
    private final NotificationRepository notificationRepository;

    public NotificationService(NotificationRepository notificationRepository) {
        this.notificationRepository = notificationRepository;
    }

    public NotificationResponse sendNotification(SendNotificationRequest request) {
        validateRequest(request);

        NotificationType type = parseType(request.type());
        NotificationChannel channel = parseChannel(request.channel());
        LocalDateTime createdAt = LocalDateTime.now();
        LocalDateTime sentAt = createdAt;
        NotificationStatus status = NotificationStatus.SENT;
        String failureReason = null;

        if (request.recipient().contains("fail") || request.message().length() > 1000) {
            status = NotificationStatus.FAILED;
            failureReason = "Notification sending failed";
            sentAt = null;
        }

        Notification notification = new Notification(
                request.orderId(),
                type,
                channel,
                request.recipient(),
                request.message(),
                status,
                failureReason,
                createdAt,
                sentAt);

        return NotificationMapper.toResponse(notificationRepository.save(notification));
    }

    public NotificationResponse getNotificationById(Long id) {
        return notificationRepository.findById(id)
                .map(NotificationMapper::toResponse)
                .orElseThrow(() -> new NotificationNotFoundException(id));
    }

    public List<NotificationResponse> getNotificationsByOrderId(Long orderId) {
        if (orderId == null || orderId <= 0) {
            throw new InvalidNotificationRequestException("Order id must be greater than 0");
        }

        return notificationRepository.findByOrderId(orderId)
                .stream()
                .map(NotificationMapper::toResponse)
                .toList();
    }

    private void validateRequest(SendNotificationRequest request) {
        if (request == null) {
            throw new InvalidNotificationRequestException("Notification request must not be null");
        }
        if (request.orderId() == null || request.orderId() <= 0) {
            throw new InvalidNotificationRequestException("Order id must be greater than 0");
        }
        if (isBlank(request.type())) {
            throw new InvalidNotificationRequestException("Notification type must not be blank");
        }
        if (isBlank(request.channel())) {
            throw new InvalidNotificationRequestException("Notification channel must not be blank");
        }
        if (isBlank(request.recipient())) {
            throw new InvalidNotificationRequestException("Notification recipient must not be blank");
        }
        if (isBlank(request.message())) {
            throw new InvalidNotificationRequestException("Notification message must not be blank");
        }
    }

    private NotificationType parseType(String value) {
        try {
            return NotificationType.valueOf(value);
        } catch (IllegalArgumentException ex) {
            throw new InvalidNotificationRequestException("Invalid notification type: " + value);
        }
    }

    private NotificationChannel parseChannel(String value) {
        try {
            return NotificationChannel.valueOf(value);
        } catch (IllegalArgumentException ex) {
            throw new InvalidNotificationRequestException("Invalid notification channel: " + value);
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
