package com.aleksandar.microbench.inventory.exception;

public class StockItemNotFoundException extends RuntimeException {

    public StockItemNotFoundException(Long productId) {
        super("Stock item not found for product id: " + productId);
    }
}
