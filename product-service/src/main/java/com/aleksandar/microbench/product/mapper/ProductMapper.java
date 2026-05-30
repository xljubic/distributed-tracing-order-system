package com.aleksandar.microbench.product.mapper;

import com.aleksandar.microbench.product.domain.Product;
import com.aleksandar.microbench.product.dto.ProductResponse;

public class ProductMapper {
    private ProductMapper() {
    }

    public static ProductResponse toResponse(Product product) {
        return new ProductResponse(
                product.getId(),
                product.getName(),
                product.getCategory(),
                product.getPrice());
    }
}
