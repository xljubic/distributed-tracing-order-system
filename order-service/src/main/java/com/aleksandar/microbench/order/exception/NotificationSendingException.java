package com.aleksandar.microbench.order.exception;

public class NotificationSendingException extends RuntimeException {

    public NotificationSendingException() {
        super("Notification sending failed");
    }
}
