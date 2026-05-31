package com.aleksandar.microbench.inventory.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.aleksandar.microbench.inventory.domain.StockReservation;

public interface StockReservationRepository extends JpaRepository<StockReservation, Long> {
}
