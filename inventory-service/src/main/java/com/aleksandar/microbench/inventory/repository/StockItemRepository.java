package com.aleksandar.microbench.inventory.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.aleksandar.microbench.inventory.domain.StockItem;

public interface StockItemRepository extends JpaRepository<StockItem, Long> {

    Optional<StockItem> findByProductId(Long productId);
}
