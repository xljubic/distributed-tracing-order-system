package com.aleksandar.microbench.order.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;

import com.aleksandar.microbench.order.domain.Order;
import com.aleksandar.microbench.order.domain.OrderItem;
import com.aleksandar.microbench.order.domain.OrderStatus;
import com.aleksandar.microbench.order.dto.CreateOrderItemRequest;
import com.aleksandar.microbench.order.dto.CreateOrderRequest;
import com.aleksandar.microbench.order.dto.OrderResponse;
import com.aleksandar.microbench.order.exception.InvalidOrderRequestException;
import com.aleksandar.microbench.order.exception.OrderNotFoundException;
import com.aleksandar.microbench.order.mapper.OrderMapper;
import com.aleksandar.microbench.order.repository.OrderRepository;

@Service
public class OrderService {
    private final OrderRepository orderRepository;

    public OrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
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

        BigDecimal totalAmount = items.stream()
                .map(OrderItem::getLineTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        LocalDateTime now = LocalDateTime.now();
        Order order = new Order(OrderStatus.CREATED, totalAmount, now, now);
        items.forEach(order::addItem);

        return OrderMapper.toResponse(orderRepository.save(order));
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

        if (item.productName() == null || item.productName().isBlank()) {
            throw new InvalidOrderRequestException("Product name must not be blank");
        }

        if (item.quantity() == null || item.quantity() <= 0) {
            throw new InvalidOrderRequestException("Order item quantity must be greater than 0");
        }

        if (item.unitPrice() == null || item.unitPrice().compareTo(BigDecimal.ZERO) <= 0) {
            throw new InvalidOrderRequestException("Order item unit price must be greater than 0");
        }
    }

    private OrderItem toOrderItem(CreateOrderItemRequest item) {
        BigDecimal lineTotal = item.unitPrice().multiply(BigDecimal.valueOf(item.quantity()));
        return new OrderItem(
                item.productId(),
                item.productName(),
                item.quantity(),
                item.unitPrice(),
                lineTotal);
    }
}
