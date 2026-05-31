package com.aleksandar.microbench.order.exception;

public class ProductNotAvailableException extends RuntimeException {

    public ProductNotAvailableException(Long productId) {
        super("Product with id " + productId + " is not available");
    }
    public ProductNotAvailableException(String message) {
        super(message);
    }

}
