package com.aleksandar.microbench.inventory.exception;

public class InvalidReservationRequestException extends RuntimeException {

    public InvalidReservationRequestException(String message) {
        super(message);
    }
}
