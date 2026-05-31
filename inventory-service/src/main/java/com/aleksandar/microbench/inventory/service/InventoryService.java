package com.aleksandar.microbench.inventory.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.aleksandar.microbench.inventory.domain.ReservationStatus;
import com.aleksandar.microbench.inventory.domain.StockItem;
import com.aleksandar.microbench.inventory.domain.StockReservation;
import com.aleksandar.microbench.inventory.dto.InventoryItemResponse;
import com.aleksandar.microbench.inventory.dto.ReserveStockItemRequest;
import com.aleksandar.microbench.inventory.dto.ReserveStockRequest;
import com.aleksandar.microbench.inventory.dto.ReserveStockResponse;
import com.aleksandar.microbench.inventory.exception.InvalidReservationRequestException;
import com.aleksandar.microbench.inventory.exception.StockItemNotFoundException;
import com.aleksandar.microbench.inventory.mapper.InventoryMapper;
import com.aleksandar.microbench.inventory.repository.StockItemRepository;
import com.aleksandar.microbench.inventory.repository.StockReservationRepository;

@Service
public class InventoryService {
    private final StockItemRepository stockItemRepository;
    private final StockReservationRepository stockReservationRepository;

    public InventoryService(
            StockItemRepository stockItemRepository,
            StockReservationRepository stockReservationRepository) {
        this.stockItemRepository = stockItemRepository;
        this.stockReservationRepository = stockReservationRepository;
    }

    public List<InventoryItemResponse> getAllStockItems() {
        return stockItemRepository.findAll()
                .stream()
                .map(InventoryMapper::toInventoryItemResponse)
                .toList();
    }

    public InventoryItemResponse getStockItemByProductId(Long productId) {
        return stockItemRepository.findByProductId(productId)
                .map(InventoryMapper::toInventoryItemResponse)
                .orElseThrow(() -> new StockItemNotFoundException(productId));
    }

    @Transactional
    public ReserveStockResponse reserveStock(ReserveStockRequest request) {
        validateRequest(request);

        List<StockReservation> reservations = request.items()
                .stream()
                .map(this::reserveItem)
                .toList();

        return InventoryMapper.toReserveStockResponse(stockReservationRepository.saveAll(reservations));
    }

    private StockReservation reserveItem(ReserveStockItemRequest item) {
        StockItem stockItem = stockItemRepository.findByProductId(item.productId())
                .orElseThrow(() -> new StockItemNotFoundException(item.productId()));

        stockItem.reserve(item.quantity());
        stockItemRepository.save(stockItem);

        return new StockReservation(
                item.productId(),
                item.quantity(),
                ReservationStatus.RESERVED,
                LocalDateTime.now());
    }

    private void validateRequest(ReserveStockRequest request) {
        if (request == null || request.items() == null || request.items().isEmpty()) {
            throw new InvalidReservationRequestException("Reservation request must contain at least one item");
        }

        request.items().forEach(this::validateItem);
    }

    private void validateItem(ReserveStockItemRequest item) {
        if (item == null) {
            throw new InvalidReservationRequestException("Reservation item must not be null");
        }
        if (item.productId() == null) {
            throw new InvalidReservationRequestException("Reservation item product id must not be null");
        }
        if (item.quantity() == null || item.quantity() <= 0) {
            throw new InvalidReservationRequestException("Reservation item quantity must be greater than 0");
        }
    }
}
