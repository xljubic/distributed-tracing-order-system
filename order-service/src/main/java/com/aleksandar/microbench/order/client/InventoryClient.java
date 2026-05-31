package com.aleksandar.microbench.order.client;

public interface InventoryClient {
    ReserveStockResponse reserveStock(ReserveStockRequest request);
}
