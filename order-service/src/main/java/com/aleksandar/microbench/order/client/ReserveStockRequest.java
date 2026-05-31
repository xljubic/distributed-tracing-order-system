package com.aleksandar.microbench.order.client;

import java.util.List;

public record ReserveStockRequest(
        List<ReserveStockItemRequest> items
    ) {

}
