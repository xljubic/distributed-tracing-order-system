package com.aleksandar.microbench.order.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.aleksandar.microbench.order.domain.Order;

public interface OrderRepository extends JpaRepository<Order, Long> {
}
