package com.aleksandar.microbench.product.service;


import java.util.List;

import org.springframework.stereotype.Service;


import com.aleksandar.microbench.product.dto.ProductResponse;
import com.aleksandar.microbench.product.exception.ProductNotFoundException;
import com.aleksandar.microbench.product.mapper.ProductMapper;
import com.aleksandar.microbench.product.repository.ProductRepository;

@Service
public class ProductService {
    public final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    public List<ProductResponse> getAllProducts() {
        return productRepository.findAll()
                .stream()
                .map(ProductMapper::toResponse)
                .toList();
    }

    public ProductResponse getProductById(Long id) {
        return productRepository.findById(id)
                .map(ProductMapper::toResponse)
                .orElseThrow(() -> new ProductNotFoundException(id));
    }

              

   
}
