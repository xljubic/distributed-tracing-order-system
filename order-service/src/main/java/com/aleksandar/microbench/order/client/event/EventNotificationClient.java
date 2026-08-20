package com.aleksandar.microbench.order.client.event;

import com.aleksandar.microbench.order.client.NotificationClient;
import com.aleksandar.microbench.order.client.NotificationResponse;
import com.aleksandar.microbench.order.client.SendNotificationRequest;
import com.aleksandar.microbench.order.event.OrderCompletedEvent;
import com.aleksandar.microbench.order.exception.EventPublicationException;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

@Component
@ConditionalOnProperty(name = "communication.notification", havingValue = "event")
public class EventNotificationClient implements NotificationClient {

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;
    private final String orderCompletedTopic;

    public EventNotificationClient(
            KafkaTemplate<String, String> kafkaTemplate,
            ObjectMapper objectMapper,
            @Value("${events.order-completed-topic}") String orderCompletedTopic) {
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
        this.orderCompletedTopic = orderCompletedTopic;
    }

    @Override
    public NotificationResponse sendNotification(SendNotificationRequest request) {
        try {
            OrderCompletedEvent event = new OrderCompletedEvent(
                    request.orderId(),
                    request.type(),
                    request.channel(),
                    request.recipient(),
                    request.message());

            kafkaTemplate.send(orderCompletedTopic, request.orderId().toString(), objectMapper.writeValueAsString(event))
                    .get(10, TimeUnit.SECONDS);

            return null;
        } catch (JsonProcessingException | InterruptedException | ExecutionException | TimeoutException ex) {
            if (ex instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            throw new EventPublicationException("Order completed event publication failed", ex);
        }
    }
}
