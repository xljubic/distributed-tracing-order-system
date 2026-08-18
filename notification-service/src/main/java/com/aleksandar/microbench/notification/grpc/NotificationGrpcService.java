package com.aleksandar.microbench.notification.grpc;

import com.aleksandar.microbench.notification.dto.NotificationResponse;
import com.aleksandar.microbench.notification.dto.SendNotificationRequest;
import com.aleksandar.microbench.notification.service.NotificationService;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import net.devh.boot.grpc.server.service.GrpcService;

@GrpcService
public class NotificationGrpcService extends NotificationSendingServiceGrpc.NotificationSendingServiceImplBase {

    private final NotificationService notificationService;

    public NotificationGrpcService(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @Override
    public void sendNotification(
            SendNotificationRequestGrpc request,
            StreamObserver<NotificationResponseGrpc> responseObserver) {
        try {
            NotificationResponse response = notificationService.sendNotification(new SendNotificationRequest(
                    request.getOrderId(),
                    request.getType(),
                    request.getChannel(),
                    request.getRecipient(),
                    request.getMessage()));

            responseObserver.onNext(NotificationResponseGrpc.newBuilder()
                    .setId(response.id())
                    .setOrderId(response.orderId())
                    .setType(response.type())
                    .setChannel(response.channel())
                    .setRecipient(response.recipient())
                    .setMessage(response.message())
                    .setStatus(response.status())
                    .setFailureReason(toGrpcString(response.failureReason()))
                    .setCreatedAt(response.createdAt().toString())
                    .setSentAt(response.sentAt() == null ? "" : response.sentAt().toString())
                    .build());
            responseObserver.onCompleted();
        } catch (RuntimeException ex) {
            responseObserver.onError(Status.INVALID_ARGUMENT
                    .withDescription(ex.getMessage())
                    .asRuntimeException());
        }
    }

    private String toGrpcString(String value) {
        return value == null ? "" : value;
    }
}
