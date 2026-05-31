package com.aleksandar.microbench.order.client;

public interface NotificationClient {

    NotificationResponse sendNotification(SendNotificationRequest request);
}
