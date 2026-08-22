package com.aleksandar.microbench.order.supplementary;

import java.math.BigDecimal;

public record LiteratureFlatProductResponse(
        Long id, String name, String category, BigDecimal price, String payload) {
}