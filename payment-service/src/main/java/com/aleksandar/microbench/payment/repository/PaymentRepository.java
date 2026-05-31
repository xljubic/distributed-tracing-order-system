package com.aleksandar.microbench.payment.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.aleksandar.microbench.payment.domain.Payment;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    List<Payment> findByOrderId(Long orderId);
}
