package com.aleksandar.microbench.product.supplementary;

import java.math.BigDecimal;

public record LiteratureNestedProductResponse(
        Product product,
        Payload payload) {
    public record Product(Long id, String name, String category, BigDecimal price) {
    }

    public record Payload(String size, String data) {
    }
}