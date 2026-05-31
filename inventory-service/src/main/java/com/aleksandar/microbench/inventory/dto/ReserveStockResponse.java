package com.aleksandar.microbench.inventory.dto;

import java.util.List;

public record ReserveStockResponse(
        String status,
        List<ReservedStockItemResponse> items) {
}
