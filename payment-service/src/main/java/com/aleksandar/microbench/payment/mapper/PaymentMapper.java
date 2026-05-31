package com.aleksandar.microbench.payment.mapper;

import com.aleksandar.microbench.payment.domain.Payment;
import com.aleksandar.microbench.payment.dto.PaymentResponse;

public class PaymentMapper {
    private PaymentMapper() {
    }

    public static PaymentResponse toResponse(Payment payment) {
        return new PaymentResponse(
                payment.getId(),
                payment.getOrderId(),
                payment.getStatus().name(),
                payment.getAmount(),
                payment.getFailureReason(),
                payment.getCreatedAt(),
                payment.getUpdatedAt());
    }
}
