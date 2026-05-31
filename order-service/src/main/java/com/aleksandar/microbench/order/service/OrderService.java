package com.aleksandar.microbench.order.service;

import com.aleksandar.microbench.order.client.InventoryClient;
import com.aleksandar.microbench.order.client.NotificationClient;
import com.aleksandar.microbench.order.client.PaymentClient;
import com.aleksandar.microbench.order.client.PaymentResponse;
import com.aleksandar.microbench.order.client.ProcessPaymentRequest;
import com.aleksandar.microbench.order.client.ProductClient;
import com.aleksandar.microbench.order.client.ProductResponse;
import com.aleksandar.microbench.order.client.ReserveStockItemRequest;
import com.aleksandar.microbench.order.client.ReserveStockRequest;
import com.aleksandar.microbench.order.client.SendNotificationRequest;
import com.aleksandar.microbench.order.domain.Order;
import com.aleksandar.microbench.order.domain.OrderItem;
import com.aleksandar.microbench.order.domain.OrderStatus;
import com.aleksandar.microbench.order.dto.CreateOrderItemRequest;
import com.aleksandar.microbench.order.dto.CreateOrderRequest;
import com.aleksandar.microbench.order.dto.OrderResponse;
import com.aleksandar.microbench.order.exception.InvalidOrderRequestException;
import com.aleksandar.microbench.order.exception.NotificationSendingException;
import com.aleksandar.microbench.order.exception.OrderNotFoundException;
import com.aleksandar.microbench.order.exception.PaymentProcessingException;
import com.aleksandar.microbench.order.mapper.OrderMapper;
import com.aleksandar.microbench.order.repository.OrderRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final ProductClient productClient;
    private final InventoryClient inventoryClient;
    private final PaymentClient paymentClient;
    private final NotificationClient notificationClient;

    public OrderService(
            OrderRepository orderRepository,
            ProductClient productClient,
            InventoryClient inventoryClient,
            PaymentClient paymentClient,
            NotificationClient notificationClient) {
        this.orderRepository = orderRepository;
        this.productClient = productClient;
        this.inventoryClient = inventoryClient;
        this.paymentClient = paymentClient;
        this.notificationClient = notificationClient;
    }

    public List<OrderResponse> getAllOrders() {
        return orderRepository.findAll()
                .stream()
                .map(OrderMapper::toResponse)
                .toList();
    }

    public OrderResponse getOrderById(Long id) {
        return orderRepository.findById(id)
                .map(OrderMapper::toResponse)
                .orElseThrow(() -> new OrderNotFoundException(id));
    }

    public OrderResponse createOrder(CreateOrderRequest request) {
        validateRequest(request);

        List<OrderItem> items = request.items()
                .stream()
                .map(this::toOrderItem)
                .toList();

        reserveStock(request);

        BigDecimal totalAmount = items.stream()
                .map(OrderItem::getLineTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        LocalDateTime now = LocalDateTime.now();
        Order order = new Order(OrderStatus.CREATED, totalAmount, now, now);
        items.forEach(order::addItem);

        Order savedOrder = orderRepository.save(order);

        try {
            processPayment(savedOrder.getId(), totalAmount);
            savedOrder.markCompleted(LocalDateTime.now());
            Order completedOrder = orderRepository.save(savedOrder);
            sendOrderCompletedNotification(completedOrder);
            return OrderMapper.toResponse(completedOrder);
        } catch (PaymentProcessingException ex) {
            savedOrder.markFailed(LocalDateTime.now());
            orderRepository.save(savedOrder);
            throw ex;
        }
    }

    private void processPayment(Long orderId, BigDecimal totalAmount) {
        PaymentResponse paymentResponse = paymentClient.processPayment(
                new ProcessPaymentRequest(orderId, totalAmount));

        if (paymentResponse == null || !"COMPLETED".equals(paymentResponse.status())) {
            throw new PaymentProcessingException("Payment processing failed");
        }
    }

    private void sendOrderCompletedNotification(Order order) {
        try {
            notificationClient.sendNotification(
                    new SendNotificationRequest(
                            order.getId(),
                            "ORDER_COMPLETED",
                            "EMAIL",
                            "customer@example.com",
                            "Order " + order.getId() + " has been completed successfully."));
        } catch (NotificationSendingException ex) {
            // Notification failure should not break the order flow.
        }
    }

    private void reserveStock(CreateOrderRequest request) {
        ReserveStockRequest reserveStockRequest = new ReserveStockRequest(
                request.items()
                        .stream()
                        .map(item -> new ReserveStockItemRequest(
                                item.productId(),
                                item.quantity()))
                        .toList());

        inventoryClient.reserveStock(reserveStockRequest);
    }

    private void validateRequest(CreateOrderRequest request) {
        if (request == null || request.items() == null || request.items().isEmpty()) {
            throw new InvalidOrderRequestException("Order must contain at least one item");
        }

        request.items().forEach(this::validateItem);
    }

    private void validateItem(CreateOrderItemRequest item) {
        if (item == null) {
            throw new InvalidOrderRequestException("Order item must not be null");
        }

        if (item.productId() == null) {
            throw new InvalidOrderRequestException("Product id must not be null");
        }

        if (item.quantity() == null || item.quantity() <= 0) {
            throw new InvalidOrderRequestException("Order item quantity must be greater than 0");
        }
    }

    private OrderItem toOrderItem(CreateOrderItemRequest item) {
        ProductResponse product = productClient.getProductById(item.productId());

        BigDecimal lineTotal = product.price().multiply(BigDecimal.valueOf(item.quantity()));

        return new OrderItem(
                product.id(),
                product.name(),
                item.quantity(),
                product.price(),
                lineTotal);
    }
}
