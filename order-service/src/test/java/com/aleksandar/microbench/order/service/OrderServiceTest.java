package com.aleksandar.microbench.order.service;

import com.aleksandar.microbench.order.client.ProductClient;
import com.aleksandar.microbench.order.client.ProductResponse;
import com.aleksandar.microbench.order.domain.Order;
import com.aleksandar.microbench.order.domain.OrderItem;
import com.aleksandar.microbench.order.domain.OrderStatus;
import com.aleksandar.microbench.order.dto.CreateOrderItemRequest;
import com.aleksandar.microbench.order.dto.CreateOrderRequest;
import com.aleksandar.microbench.order.dto.OrderResponse;
import com.aleksandar.microbench.order.exception.InvalidOrderRequestException;
import com.aleksandar.microbench.order.exception.OrderNotFoundException;
import com.aleksandar.microbench.order.repository.OrderRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private ProductClient productClient;

    @InjectMocks
    private OrderService orderService;

    @Test
    void shouldCreateOrder() {
        CreateOrderRequest request = new CreateOrderRequest(
                List.of(
                        new CreateOrderItemRequest(1L, 2),
                        new CreateOrderItemRequest(2L, 1)
                )
        );

        when(productClient.getProductById(1L)).thenReturn(
                new ProductResponse(1L, "Lenovo ThinkPad E16", "Laptop", new BigDecimal("899.99"))
        );

        when(productClient.getProductById(2L)).thenReturn(
                new ProductResponse(2L, "iPhone 15", "Phone", new BigDecimal("999.99"))
        );

        when(orderRepository.save(any(Order.class))).thenAnswer(invocation -> invocation.getArgument(0));

        OrderResponse result = orderService.createOrder(request);

        assertEquals("CREATED", result.status());
        assertEquals(new BigDecimal("2799.97"), result.totalAmount());
        assertEquals(2, result.items().size());

        assertEquals(1L, result.items().get(0).productId());
        assertEquals("Lenovo ThinkPad E16", result.items().get(0).productName());
        assertEquals(2, result.items().get(0).quantity());
        assertEquals(new BigDecimal("899.99"), result.items().get(0).unitPrice());
        assertEquals(new BigDecimal("1799.98"), result.items().get(0).lineTotal());

        assertEquals(2L, result.items().get(1).productId());
        assertEquals("iPhone 15", result.items().get(1).productName());
        assertEquals(1, result.items().get(1).quantity());
        assertEquals(new BigDecimal("999.99"), result.items().get(1).unitPrice());
        assertEquals(new BigDecimal("999.99"), result.items().get(1).lineTotal());
    }

    @Test
    void shouldReturnOrderByIdWhenOrderExists() {
        LocalDateTime now = LocalDateTime.now();

        Order order = new Order(OrderStatus.CREATED, new BigDecimal("1799.98"), now, now);
        order.addItem(new OrderItem(
                1L,
                "Lenovo ThinkPad E16",
                2,
                new BigDecimal("899.99"),
                new BigDecimal("1799.98")
        ));

        when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

        OrderResponse result = orderService.getOrderById(1L);

        assertEquals("CREATED", result.status());
        assertEquals(new BigDecimal("1799.98"), result.totalAmount());
        assertEquals(1, result.items().size());
        assertEquals("Lenovo ThinkPad E16", result.items().get(0).productName());
    }

    @Test
    void shouldThrowExceptionWhenOrderDoesNotExist() {
        when(orderRepository.findById(999L)).thenReturn(Optional.empty());

        OrderNotFoundException exception = assertThrows(
                OrderNotFoundException.class,
                () -> orderService.getOrderById(999L)
        );

        assertEquals("Order not found with id: 999", exception.getMessage());
    }

    @Test
    void shouldThrowExceptionWhenCreateOrderRequestHasNoItems() {
        CreateOrderRequest request = new CreateOrderRequest(List.of());

        InvalidOrderRequestException exception = assertThrows(
                InvalidOrderRequestException.class,
                () -> orderService.createOrder(request)
        );

        assertEquals("Order must contain at least one item", exception.getMessage());
    }
}