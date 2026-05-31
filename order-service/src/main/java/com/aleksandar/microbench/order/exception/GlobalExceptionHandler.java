package com.aleksandar.microbench.order.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.aleksandar.microbench.order.dto.ErrorResponse;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(OrderNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleOrderNotFoundException(OrderNotFoundException ex) {
        return new ErrorResponse(ex.getMessage());
    }

    @ExceptionHandler(InvalidOrderRequestException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleInvalidOrderRequestException(InvalidOrderRequestException ex) {
        return new ErrorResponse(ex.getMessage());
    }

    @ExceptionHandler(ProductNotAvailableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleProductNotAvailableException(ProductNotAvailableException ex) {
        return new ErrorResponse(ex.getMessage());
    }

    @ExceptionHandler(InventoryReservationException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleInventoryReservationException(InventoryReservationException ex) {
        return new ErrorResponse(ex.getMessage());
    }
}
