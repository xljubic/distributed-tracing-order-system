package com.aleksandar.microbench.order.grpc;

import com.aleksandar.microbench.notification.grpc.NotificationResponseGrpc;
import com.aleksandar.microbench.notification.grpc.NotificationSendingServiceGrpc;
import com.aleksandar.microbench.notification.grpc.SendNotificationRequestGrpc;
import com.aleksandar.microbench.order.client.NotificationClient;
import com.aleksandar.microbench.order.client.NotificationResponse;
import com.aleksandar.microbench.order.client.SendNotificationRequest;
import com.aleksandar.microbench.order.exception.NotificationSendingException;
import io.grpc.StatusRuntimeException;
import net.devh.boot.grpc.client.inject.GrpcClient;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
@ConditionalOnProperty(name = "communication.notification", havingValue = "grpc")
public class GrpcNotificationClient implements NotificationClient {

    @GrpcClient("notification-service")
    private NotificationSendingServiceGrpc.NotificationSendingServiceBlockingStub notificationStub;

    @Override
    public NotificationResponse sendNotification(SendNotificationRequest request) {
        try {
            NotificationResponseGrpc response = notificationStub.sendNotification(
                    SendNotificationRequestGrpc.newBuilder()
                            .setOrderId(request.orderId())
                            .setType(request.type())
                            .setChannel(request.channel())
                            .setRecipient(request.recipient())
                            .setMessage(request.message())
                            .build());

            return new NotificationResponse(
                    response.getId(),
                    response.getOrderId(),
                    response.getType(),
                    response.getChannel(),
                    response.getRecipient(),
                    response.getMessage(),
                    response.getStatus(),
                    emptyToNull(response.getFailureReason()),
                    LocalDateTime.parse(response.getCreatedAt()),
                    response.getSentAt().isBlank() ? null : LocalDateTime.parse(response.getSentAt()));
        } catch (StatusRuntimeException ex) {
            throw new NotificationSendingException();
        }
    }

    private String emptyToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
