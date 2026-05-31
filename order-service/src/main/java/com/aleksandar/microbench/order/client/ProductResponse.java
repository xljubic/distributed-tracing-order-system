package com.aleksandar.microbench.order.client;

import java.math.BigDecimal;

public record ProductResponse(
        Long id,
        String name,
        String category,
        BigDecimal price) {

}
