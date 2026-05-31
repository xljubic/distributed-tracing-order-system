package com.aleksandar.microbench.inventory.dto;

import java.util.List;

public record ReserveStockRequest(List<ReserveStockItemRequest> items) {
}
