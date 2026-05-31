package com.aleksandar.microbench.inventory.service;

import com.aleksandar.microbench.inventory.domain.StockItem;
import com.aleksandar.microbench.inventory.domain.StockReservation;
import com.aleksandar.microbench.inventory.dto.InventoryItemResponse;
import com.aleksandar.microbench.inventory.dto.ReserveStockItemRequest;
import com.aleksandar.microbench.inventory.dto.ReserveStockRequest;
import com.aleksandar.microbench.inventory.dto.ReserveStockResponse;
import com.aleksandar.microbench.inventory.exception.InsufficientStockException;
import com.aleksandar.microbench.inventory.exception.InvalidReservationRequestException;
import com.aleksandar.microbench.inventory.exception.StockItemNotFoundException;
import com.aleksandar.microbench.inventory.repository.StockItemRepository;
import com.aleksandar.microbench.inventory.repository.StockReservationRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class InventoryServiceTest {

    @Mock
    private StockItemRepository stockItemRepository;

    @Mock
    private StockReservationRepository stockReservationRepository;

    @InjectMocks
    private InventoryService inventoryService;

    @Test
    void shouldReturnAllStockItems() {
        StockItem laptopStock = new StockItem(1L, 20, 0);
        StockItem phoneStock = new StockItem(2L, 15, 0);

        when(stockItemRepository.findAll()).thenReturn(List.of(laptopStock, phoneStock));

        List<InventoryItemResponse> result = inventoryService.getAllStockItems();

        assertEquals(2, result.size());
        assertEquals(1L, result.get(0).productId());
        assertEquals(20, result.get(0).availableQuantity());
        assertEquals(2L, result.get(1).productId());
    }

    @Test
    void shouldReturnStockItemByProductId() {
        StockItem stockItem = new StockItem(1L, 20, 0);

        when(stockItemRepository.findByProductId(1L)).thenReturn(Optional.of(stockItem));

        InventoryItemResponse result = inventoryService.getStockItemByProductId(1L);

        assertEquals(1L, result.productId());
        assertEquals(20, result.availableQuantity());
        assertEquals(0, result.reservedQuantity());
    }

    @Test
    void shouldThrowExceptionWhenStockItemDoesNotExist() {
        when(stockItemRepository.findByProductId(999L)).thenReturn(Optional.empty());

        StockItemNotFoundException exception = assertThrows(
                StockItemNotFoundException.class,
                () -> inventoryService.getStockItemByProductId(999L));

        assertEquals("Stock item not found for product id: 999", exception.getMessage());
    }

    @Test
    void shouldReserveStock() {
        StockItem stockItem = new StockItem(1L, 20, 0);
        ReserveStockRequest request = new ReserveStockRequest(List.of(
                new ReserveStockItemRequest(1L, 3)));

        when(stockItemRepository.findByProductId(1L)).thenReturn(Optional.of(stockItem));
        when(stockReservationRepository.saveAll(anyList()))
                .thenAnswer(invocation -> invocation.getArgument(0));

        ReserveStockResponse result = inventoryService.reserveStock(request);

        assertEquals("RESERVED", result.status());
        assertEquals(1, result.items().size());
        assertEquals(1L, result.items().get(0).productId());
        assertEquals(3, result.items().get(0).quantity());
        assertEquals("RESERVED", result.items().get(0).status());
        assertEquals(17, stockItem.getAvailableQuantity());
        assertEquals(3, stockItem.getReservedQuantity());
    }

    @Test
    void shouldThrowExceptionWhenRequestHasNoItems() {
        ReserveStockRequest request = new ReserveStockRequest(List.of());

        InvalidReservationRequestException exception = assertThrows(
                InvalidReservationRequestException.class,
                () -> inventoryService.reserveStock(request));

        assertEquals("Reservation request must contain at least one item", exception.getMessage());
    }

    @Test
    void shouldThrowExceptionWhenQuantityIsInvalid() {
        ReserveStockRequest request = new ReserveStockRequest(List.of(
                new ReserveStockItemRequest(1L, 0)));

        InvalidReservationRequestException exception = assertThrows(
                InvalidReservationRequestException.class,
                () -> inventoryService.reserveStock(request));

        assertEquals("Reservation item quantity must be greater than 0", exception.getMessage());
    }

    @Test
    void shouldThrowExceptionWhenInsufficientStock() {
        StockItem stockItem = new StockItem(1L, 2, 0);
        ReserveStockRequest request = new ReserveStockRequest(List.of(
                new ReserveStockItemRequest(1L, 3)));

        when(stockItemRepository.findByProductId(1L)).thenReturn(Optional.of(stockItem));

        InsufficientStockException exception = assertThrows(
                InsufficientStockException.class,
                () -> inventoryService.reserveStock(request));

        assertEquals("Insufficient stock for product id: 1", exception.getMessage());
    }
}
