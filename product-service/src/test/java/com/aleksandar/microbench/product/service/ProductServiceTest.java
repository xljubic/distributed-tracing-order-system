package com.aleksandar.microbench.product.service;

import com.aleksandar.microbench.product.domain.Product;
import com.aleksandar.microbench.product.dto.ProductResponse;
import com.aleksandar.microbench.product.exception.ProductNotFoundException;
import com.aleksandar.microbench.product.repository.ProductRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {

    @Mock
    private ProductRepository productRepository;

    @InjectMocks
    private ProductService productService;

    @Test
    void shouldReturnAllProducts() {
        Product laptop = new Product(1L, "Lenovo ThinkPad E16", "Laptop", new BigDecimal("899.99"));
        Product phone = new Product(2L, "iPhone 15", "Phone", new BigDecimal("999.99"));

        when(productRepository.findAll()).thenReturn(List.of(laptop, phone));

        List<ProductResponse> result = productService.getAllProducts();

        assertEquals(2, result.size());
        assertEquals("Lenovo ThinkPad E16", result.get(0).name());
        assertEquals("iPhone 15", result.get(1).name());
    }

    @Test
    void shouldReturnProductByIdWhenProductExists() {
        Product product = new Product(1L, "Lenovo ThinkPad E16", "Laptop", new BigDecimal("899.99"));

        when(productRepository.findById(1L)).thenReturn(Optional.of(product));

        ProductResponse result = productService.getProductById(1L);

        assertEquals(1L, result.id());
        assertEquals("Lenovo ThinkPad E16", result.name());
        assertEquals("Laptop", result.category());
        assertEquals(new BigDecimal("899.99"), result.price());
    }

    @Test
    void shouldThrowExceptionWhenProductDoesNotExist() {
        when(productRepository.findById(999L)).thenReturn(Optional.empty());

        ProductNotFoundException exception = assertThrows(
                ProductNotFoundException.class,
                () -> productService.getProductById(999L));

        assertEquals("Product not found with id: 999", exception.getMessage());
    }
}