package com.aleksandar.microbench.notification.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.aleksandar.microbench.notification.dto.NotificationResponse;
import com.aleksandar.microbench.notification.dto.SendNotificationRequest;
import com.aleksandar.microbench.notification.service.NotificationService;

@RestController
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @PostMapping("/api/notifications")
    @ResponseStatus(HttpStatus.CREATED)
    public NotificationResponse sendNotification(@RequestBody SendNotificationRequest request) {
        return notificationService.sendNotification(request);
    }

    @GetMapping("/api/notifications/{id}")
    public NotificationResponse getNotificationById(@PathVariable("id") Long id) {
        return notificationService.getNotificationById(id);
    }

    @GetMapping("/api/notifications/order/{orderId}")
    public List<NotificationResponse> getNotificationsByOrderId(@PathVariable("orderId") Long orderId) {
        return notificationService.getNotificationsByOrderId(orderId);
    }
}
