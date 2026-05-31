package com.aleksandar.microbench.inventory.mapper;

import java.util.List;

import com.aleksandar.microbench.inventory.domain.StockItem;
import com.aleksandar.microbench.inventory.domain.StockReservation;
import com.aleksandar.microbench.inventory.dto.InventoryItemResponse;
import com.aleksandar.microbench.inventory.dto.ReserveStockResponse;
import com.aleksandar.microbench.inventory.dto.ReservedStockItemResponse;

public class InventoryMapper {
    private InventoryMapper() {
    }

    public static InventoryItemResponse toInventoryItemResponse(StockItem stockItem) {
        return new InventoryItemResponse(
                stockItem.getProductId(),
                stockItem.getAvailableQuantity(),
                stockItem.getReservedQuantity());
    }

    public static ReservedStockItemResponse toReservedStockItemResponse(StockReservation reservation) {
        return new ReservedStockItemResponse(
                reservation.getProductId(),
                reservation.getQuantity(),
                reservation.getStatus().name());
    }

    public static ReserveStockResponse toReserveStockResponse(List<StockReservation> reservations) {
        return new ReserveStockResponse(
                "RESERVED",
                reservations.stream()
                        .map(InventoryMapper::toReservedStockItemResponse)
                        .toList());
    }
}
