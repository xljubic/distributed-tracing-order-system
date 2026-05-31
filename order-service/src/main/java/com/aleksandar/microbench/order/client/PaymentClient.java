package com.aleksandar.microbench.order.client;

public interface PaymentClient {

    PaymentResponse processPayment(ProcessPaymentRequest request);
}
