package com.aleksandar.microbench.product.supplementary;

import java.math.BigDecimal;

public record LiteratureProductResponse(
        Long id,
        String name,
        String category,
        BigDecimal price,
        String payload) {
}