package com.aleksandar.microbench.product.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.aleksandar.microbench.product.domain.Product;

public interface ProductRepository extends JpaRepository<Product, Long> {

}
