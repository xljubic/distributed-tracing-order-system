package com.aleksandar.microbench.notification.service;

import com.aleksandar.microbench.notification.domain.Notification;
import com.aleksandar.microbench.notification.domain.NotificationChannel;
import com.aleksandar.microbench.notification.domain.NotificationStatus;
import com.aleksandar.microbench.notification.domain.NotificationType;
import com.aleksandar.microbench.notification.dto.NotificationResponse;
import com.aleksandar.microbench.notification.dto.SendNotificationRequest;
import com.aleksandar.microbench.notification.exception.InvalidNotificationRequestException;
import com.aleksandar.microbench.notification.exception.NotificationNotFoundException;
import com.aleksandar.microbench.notification.repository.NotificationRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock
    private NotificationRepository notificationRepository;

    @InjectMocks
    private NotificationService notificationService;

    @Test
    void shouldSendNotificationSuccessfully() {
        SendNotificationRequest request = new SendNotificationRequest(
                1L,
                "ORDER_COMPLETED",
                "EMAIL",
                "customer@example.com",
                "Order 1 has been completed successfully.");

        when(notificationRepository.save(any(Notification.class))).thenAnswer(invocation -> invocation.getArgument(0));

        NotificationResponse result = notificationService.sendNotification(request);

        assertEquals(1L, result.orderId());
        assertEquals("ORDER_COMPLETED", result.type());
        assertEquals("EMAIL", result.channel());
        assertEquals("SENT", result.status());
        assertNull(result.failureReason());
        assertNotNull(result.sentAt());
    }

    @Test
    void shouldCreateFailedNotificationWhenSendingFails() {
        SendNotificationRequest request = new SendNotificationRequest(
                1L,
                "ORDER_COMPLETED",
                "EMAIL",
                "fail@example.com",
                "Order 1 has been completed successfully.");

        when(notificationRepository.save(any(Notification.class))).thenAnswer(invocation -> invocation.getArgument(0));

        NotificationResponse result = notificationService.sendNotification(request);

        assertEquals("FAILED", result.status());
        assertEquals("Notification sending failed", result.failureReason());
        assertNull(result.sentAt());
    }

    @Test
    void shouldReturnNotificationByIdWhenExists() {
        LocalDateTime now = LocalDateTime.now();
        Notification notification = new Notification(
                1L,
                NotificationType.ORDER_COMPLETED,
                NotificationChannel.EMAIL,
                "customer@example.com",
                "Order 1 has been completed successfully.",
                NotificationStatus.SENT,
                null,
                now,
                now);

        when(notificationRepository.findById(1L)).thenReturn(Optional.of(notification));

        NotificationResponse result = notificationService.getNotificationById(1L);

        assertEquals(1L, result.orderId());
        assertEquals("ORDER_COMPLETED", result.type());
        assertEquals("SENT", result.status());
    }

    @Test
    void shouldThrowExceptionWhenNotificationDoesNotExist() {
        when(notificationRepository.findById(999L)).thenReturn(Optional.empty());

        NotificationNotFoundException exception = assertThrows(
                NotificationNotFoundException.class,
                () -> notificationService.getNotificationById(999L));

        assertEquals("Notification not found with id: 999", exception.getMessage());
    }

    @Test
    void shouldReturnNotificationsByOrderId() {
        LocalDateTime now = LocalDateTime.now();
        Notification first = new Notification(
                1L,
                NotificationType.ORDER_COMPLETED,
                NotificationChannel.EMAIL,
                "customer@example.com",
                "Order 1 has been completed successfully.",
                NotificationStatus.SENT,
                null,
                now,
                now);
        Notification second = new Notification(
                1L,
                NotificationType.ORDER_FAILED,
                NotificationChannel.SMS,
                "customer@example.com",
                "Order 1 failed.",
                NotificationStatus.SENT,
                null,
                now,
                now);

        when(notificationRepository.findByOrderId(1L)).thenReturn(List.of(first, second));

        List<NotificationResponse> result = notificationService.getNotificationsByOrderId(1L);

        assertEquals(2, result.size());
        assertEquals(1L, result.get(0).orderId());
        assertEquals("ORDER_FAILED", result.get(1).type());
    }

    @Test
    void shouldThrowExceptionWhenRequestIsInvalid() {
        SendNotificationRequest request = new SendNotificationRequest(
                1L,
                "UNKNOWN",
                "EMAIL",
                "customer@example.com",
                "Order 1 has been completed successfully.");

        InvalidNotificationRequestException exception = assertThrows(
                InvalidNotificationRequestException.class,
                () -> notificationService.sendNotification(request));

        assertEquals("Invalid notification type: UNKNOWN", exception.getMessage());
    }

    @Test
    void shouldThrowExceptionWhenOrderIdIsInvalid() {
        InvalidNotificationRequestException exception = assertThrows(
                InvalidNotificationRequestException.class,
                () -> notificationService.getNotificationsByOrderId(null));

        assertEquals("Order id must be greater than 0", exception.getMessage());
    }
}
