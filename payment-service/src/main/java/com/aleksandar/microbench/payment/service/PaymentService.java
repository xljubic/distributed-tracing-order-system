package com.aleksandar.microbench.payment.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;

import com.aleksandar.microbench.payment.domain.Payment;
import com.aleksandar.microbench.payment.domain.PaymentStatus;
import com.aleksandar.microbench.payment.dto.PaymentResponse;
import com.aleksandar.microbench.payment.dto.ProcessPaymentRequest;
import com.aleksandar.microbench.payment.exception.InvalidPaymentRequestException;
import com.aleksandar.microbench.payment.exception.PaymentNotFoundException;
import com.aleksandar.microbench.payment.mapper.PaymentMapper;
import com.aleksandar.microbench.payment.repository.PaymentRepository;

@Service
public class PaymentService {
    private static final BigDecimal PAYMENT_LIMIT = new BigDecimal("10000");

    private final PaymentRepository paymentRepository;

    public PaymentService(PaymentRepository paymentRepository) {
        this.paymentRepository = paymentRepository;
    }

    public PaymentResponse processPayment(ProcessPaymentRequest request) {
        validateRequest(request);

        PaymentStatus status = PaymentStatus.COMPLETED;
        String failureReason = null;

        if (request.amount().compareTo(PAYMENT_LIMIT) > 0) {
            status = PaymentStatus.FAILED;
            failureReason = "Payment amount exceeds allowed limit";
        }

        LocalDateTime now = LocalDateTime.now();
        Payment payment = new Payment(
                request.orderId(),
                request.amount(),
                status,
                failureReason,
                now,
                now);

        return PaymentMapper.toResponse(paymentRepository.save(payment));
    }

    public PaymentResponse getPaymentById(Long id) {
        return paymentRepository.findById(id)
                .map(PaymentMapper::toResponse)
                .orElseThrow(() -> new PaymentNotFoundException(id));
    }

    public List<PaymentResponse> getPaymentsByOrderId(Long orderId) {
        if (orderId == null || orderId <= 0) {
            throw new InvalidPaymentRequestException("Order id must be greater than 0");
        }

        return paymentRepository.findByOrderId(orderId)
                .stream()
                .map(PaymentMapper::toResponse)
                .toList();
    }

    private void validateRequest(ProcessPaymentRequest request) {
        if (request == null) {
            throw new InvalidPaymentRequestException("Payment request must not be null");
        }
        if (request.orderId() == null) {
            throw new InvalidPaymentRequestException("Order id must not be null");
        }
        if (request.amount() == null) {
            throw new InvalidPaymentRequestException("Payment amount must not be null");
        }
        if (request.amount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new InvalidPaymentRequestException("Payment amount must be greater than 0");
        }
    }
}
