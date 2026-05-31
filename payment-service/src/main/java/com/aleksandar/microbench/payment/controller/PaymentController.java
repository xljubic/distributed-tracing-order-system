package com.aleksandar.microbench.payment.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.aleksandar.microbench.payment.dto.PaymentResponse;
import com.aleksandar.microbench.payment.dto.ProcessPaymentRequest;
import com.aleksandar.microbench.payment.service.PaymentService;

@RestController
public class PaymentController {

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @PostMapping("/api/payments")
    @ResponseStatus(HttpStatus.CREATED)
    public PaymentResponse processPayment(@RequestBody ProcessPaymentRequest request) {
        return paymentService.processPayment(request);
    }

    @GetMapping("/api/payments/{id}")
    public PaymentResponse getPaymentById(@PathVariable("id") Long id) {
        return paymentService.getPaymentById(id);
    }

    @GetMapping("/api/payments/order/{orderId}")
    public List<PaymentResponse> getPaymentsByOrderId(@PathVariable("orderId") Long orderId) {
        return paymentService.getPaymentsByOrderId(orderId);
    }
}
