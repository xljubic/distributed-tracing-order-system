package com.aleksandar.microbench.order.client.rest;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.aleksandar.microbench.order.client.NotificationClient;
import com.aleksandar.microbench.order.client.NotificationResponse;
import com.aleksandar.microbench.order.client.SendNotificationRequest;
import com.aleksandar.microbench.order.exception.NotificationSendingException;

@Component
public class RestNotificationClient implements NotificationClient {

    private final RestClient restClient;

    public RestNotificationClient(
            RestClient.Builder restClientBuilder,
            @Value("${services.notification-service.url}") String notificationServiceUrl) {
        this.restClient = restClientBuilder
                .baseUrl(notificationServiceUrl)
                .build();
    }

    @Override
    public NotificationResponse sendNotification(SendNotificationRequest request) {
        try {
            return restClient
                    .post()
                    .uri("/api/notifications")
                    .body(request)
                    .retrieve()
                    .body(NotificationResponse.class);
        } catch (RestClientException ex) {
            throw new NotificationSendingException();
        }
    }
}
