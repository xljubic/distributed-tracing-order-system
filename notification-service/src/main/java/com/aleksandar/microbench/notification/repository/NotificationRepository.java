package com.aleksandar.microbench.notification.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.aleksandar.microbench.notification.domain.Notification;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    List<Notification> findByOrderId(Long orderId);
}
