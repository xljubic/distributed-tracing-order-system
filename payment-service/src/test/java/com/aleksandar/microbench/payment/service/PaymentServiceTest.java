package com.aleksandar.microbench.payment.service;

import com.aleksandar.microbench.payment.domain.Payment;
import com.aleksandar.microbench.payment.domain.PaymentStatus;
import com.aleksandar.microbench.payment.dto.PaymentResponse;
import com.aleksandar.microbench.payment.dto.ProcessPaymentRequest;
import com.aleksandar.microbench.payment.exception.InvalidPaymentRequestException;
import com.aleksandar.microbench.payment.exception.PaymentNotFoundException;
import com.aleksandar.microbench.payment.repository.PaymentRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentServiceTest {

    @Mock
    private PaymentRepository paymentRepository;

    @InjectMocks
    private PaymentService paymentService;

    @Test
    void shouldProcessSuccessfulPayment() {
        ProcessPaymentRequest request = new ProcessPaymentRequest(1L, new BigDecimal("2799.97"));

        when(paymentRepository.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        PaymentResponse result = paymentService.processPayment(request);

        assertEquals(1L, result.orderId());
        assertEquals(new BigDecimal("2799.97"), result.amount());
        assertEquals("COMPLETED", result.status());
        assertNull(result.failureReason());
    }

    @Test
    void shouldProcessFailedPaymentWhenAmountExceedsLimit() {
        ProcessPaymentRequest request = new ProcessPaymentRequest(1L, new BigDecimal("10000.01"));

        when(paymentRepository.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        PaymentResponse result = paymentService.processPayment(request);

        assertEquals("FAILED", result.status());
        assertEquals("Payment amount exceeds allowed limit", result.failureReason());
    }

    @Test
    void shouldReturnPaymentByIdWhenPaymentExists() {
        LocalDateTime now = LocalDateTime.now();
        Payment payment = new Payment(
                1L,
                new BigDecimal("2799.97"),
                PaymentStatus.COMPLETED,
                null,
                now,
                now);

        when(paymentRepository.findById(1L)).thenReturn(Optional.of(payment));

        PaymentResponse result = paymentService.getPaymentById(1L);

        assertEquals(1L, result.orderId());
        assertEquals("COMPLETED", result.status());
        assertEquals(new BigDecimal("2799.97"), result.amount());
    }

    @Test
    void shouldThrowExceptionWhenPaymentDoesNotExist() {
        when(paymentRepository.findById(999L)).thenReturn(Optional.empty());

        PaymentNotFoundException exception = assertThrows(
                PaymentNotFoundException.class,
                () -> paymentService.getPaymentById(999L));

        assertEquals("Payment not found with id: 999", exception.getMessage());
    }

    @Test
    void shouldReturnPaymentsByOrderId() {
        LocalDateTime now = LocalDateTime.now();
        Payment firstPayment = new Payment(
                1L,
                new BigDecimal("899.99"),
                PaymentStatus.COMPLETED,
                null,
                now,
                now);
        Payment secondPayment = new Payment(
                1L,
                new BigDecimal("999.99"),
                PaymentStatus.COMPLETED,
                null,
                now,
                now);

        when(paymentRepository.findByOrderId(1L)).thenReturn(List.of(firstPayment, secondPayment));

        List<PaymentResponse> result = paymentService.getPaymentsByOrderId(1L);

        assertEquals(2, result.size());
        assertEquals(1L, result.get(0).orderId());
        assertEquals(new BigDecimal("899.99"), result.get(0).amount());
        assertEquals(new BigDecimal("999.99"), result.get(1).amount());
    }

    @Test
    void shouldThrowExceptionWhenRequestIsInvalid() {
        ProcessPaymentRequest request = new ProcessPaymentRequest(1L, BigDecimal.ZERO);

        InvalidPaymentRequestException exception = assertThrows(
                InvalidPaymentRequestException.class,
                () -> paymentService.processPayment(request));

        assertEquals("Payment amount must be greater than 0", exception.getMessage());
    }

    @Test
    void shouldThrowExceptionWhenOrderIdIsInvalid() {
        InvalidPaymentRequestException exception = assertThrows(
                InvalidPaymentRequestException.class,
                () -> paymentService.getPaymentsByOrderId(null));

        assertEquals("Order id must be greater than 0", exception.getMessage());
    }
}
