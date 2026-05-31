package com.aleksandar.microbench.order.client;

import java.util.List;

public record ReserveStockResponse(
        String status,
        List<ReservedStockItemResponse> items
    ) {

}
