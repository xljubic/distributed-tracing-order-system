package com.aleksandar.microbench.order.grpc;

import com.aleksandar.microbench.order.client.PaymentClient;
import com.aleksandar.microbench.order.client.PaymentResponse;
import com.aleksandar.microbench.order.client.ProcessPaymentRequest;
import com.aleksandar.microbench.order.exception.PaymentProcessingException;
import com.aleksandar.microbench.payment.grpc.PaymentProcessingServiceGrpc;
import com.aleksandar.microbench.payment.grpc.PaymentResponseGrpc;
import com.aleksandar.microbench.payment.grpc.ProcessPaymentRequestGrpc;
import io.grpc.StatusRuntimeException;
import net.devh.boot.grpc.client.inject.GrpcClient;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Component
@ConditionalOnProperty(name = "communication.payment", havingValue = "grpc")
public class GrpcPaymentClient implements PaymentClient {

    @GrpcClient("payment-service")
    private PaymentProcessingServiceGrpc.PaymentProcessingServiceBlockingStub paymentStub;

    @Override
    public PaymentResponse processPayment(ProcessPaymentRequest request) {
        try {
            PaymentResponseGrpc response = paymentStub.processPayment(
                    ProcessPaymentRequestGrpc.newBuilder()
                            .setOrderId(request.orderId())
                            .setAmount(request.amount().toPlainString())
                            .build());

            return new PaymentResponse(
                    response.getPaymentId(),
                    response.getOrderId(),
                    response.getStatus(),
                    new BigDecimal(response.getAmount()),
                    emptyToNull(response.getFailureReason()),
                    LocalDateTime.parse(response.getCreatedAt()),
                    LocalDateTime.parse(response.getUpdatedAt()));
        } catch (StatusRuntimeException ex) {
            throw new PaymentProcessingException("Payment processing failed");
        }
    }

    private String emptyToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
