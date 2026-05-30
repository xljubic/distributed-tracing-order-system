package com.aleksandar.microbench.product.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import com.aleksandar.microbench.product.dto.ProductResponse;
import com.aleksandar.microbench.product.service.ProductService;



@RestController
public class ProductController {

    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping("/api/products")
    public List<ProductResponse> getAllProducts() {
        return productService.getAllProducts();
    }
    @GetMapping("/api/products/{id}")
    public ProductResponse getProductById(@PathVariable("id") Long id) {
        return productService.getProductById(id);
    }
    
}
