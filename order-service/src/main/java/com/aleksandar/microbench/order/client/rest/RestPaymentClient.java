package com.aleksandar.microbench.order.client.rest;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.aleksandar.microbench.order.client.PaymentClient;
import com.aleksandar.microbench.order.client.PaymentResponse;
import com.aleksandar.microbench.order.client.ProcessPaymentRequest;
import com.aleksandar.microbench.order.exception.PaymentProcessingException;

@Component
public class RestPaymentClient implements PaymentClient {

    private final RestClient restClient;

    public RestPaymentClient(
            RestClient.Builder restClientBuilder,
            @Value("${services.payment-service.url}") String paymentServiceUrl) {
        this.restClient = restClientBuilder
                .baseUrl(paymentServiceUrl)
                .build();
    }

    @Override
    public PaymentResponse processPayment(ProcessPaymentRequest request) {
        try {
            return restClient
                    .post()
                    .uri("/api/payments")
                    .body(request)
                    .retrieve()
                    .body(PaymentResponse.class);
        } catch (RestClientException ex) {
            throw new PaymentProcessingException("Payment processing failed");
        }
    }
}
