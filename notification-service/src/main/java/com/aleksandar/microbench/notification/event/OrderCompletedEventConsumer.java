package com.aleksandar.microbench.notification.event;

import com.aleksandar.microbench.notification.dto.NotificationResponse;
import com.aleksandar.microbench.notification.dto.SendNotificationRequest;
import com.aleksandar.microbench.notification.service.NotificationService;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Component
public class OrderCompletedEventConsumer {

    private static final Logger log = LoggerFactory.getLogger(OrderCompletedEventConsumer.class);

    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;

    public OrderCompletedEventConsumer(NotificationService notificationService, ObjectMapper objectMapper) {
        this.notificationService = notificationService;
        this.objectMapper = objectMapper;
    }

    @KafkaListener(topics = "${events.order-completed-topic}")
    public void consume(ConsumerRecord<String, String> record) throws JsonProcessingException {
        OrderCompletedEvent event = objectMapper.readValue(record.value(), OrderCompletedEvent.class);

        NotificationResponse response = notificationService.sendNotification(new SendNotificationRequest(
                event.orderId(),
                event.type(),
                event.channel(),
                event.recipient(),
                event.message()));

        log.info(
                "Processed OrderCompleted event for orderId={} into notificationId={}",
                event.orderId(),
                response.id());
    }
}
