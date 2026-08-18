package com.aleksandar.microbench.payment.grpc;

import com.aleksandar.microbench.payment.dto.PaymentResponse;
import com.aleksandar.microbench.payment.dto.ProcessPaymentRequest;
import com.aleksandar.microbench.payment.service.PaymentService;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import net.devh.boot.grpc.server.service.GrpcService;

import java.math.BigDecimal;

@GrpcService
public class PaymentGrpcService extends PaymentProcessingServiceGrpc.PaymentProcessingServiceImplBase {

    private final PaymentService paymentService;

    public PaymentGrpcService(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @Override
    public void processPayment(
            ProcessPaymentRequestGrpc request,
            StreamObserver<PaymentResponseGrpc> responseObserver) {
        try {
            PaymentResponse response = paymentService.processPayment(new ProcessPaymentRequest(
                    request.getOrderId(),
                    new BigDecimal(request.getAmount())));

            responseObserver.onNext(PaymentResponseGrpc.newBuilder()
                    .setPaymentId(response.paymentId())
                    .setOrderId(response.orderId())
                    .setStatus(response.status())
                    .setAmount(response.amount().toPlainString())
                    .setFailureReason(toGrpcString(response.failureReason()))
                    .setCreatedAt(response.createdAt().toString())
                    .setUpdatedAt(response.updatedAt().toString())
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
