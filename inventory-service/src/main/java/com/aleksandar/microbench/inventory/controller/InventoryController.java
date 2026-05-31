package com.aleksandar.microbench.inventory.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.aleksandar.microbench.inventory.dto.InventoryItemResponse;
import com.aleksandar.microbench.inventory.dto.ReserveStockRequest;
import com.aleksandar.microbench.inventory.dto.ReserveStockResponse;
import com.aleksandar.microbench.inventory.service.InventoryService;

@RestController
public class InventoryController {

    private final InventoryService inventoryService;

    public InventoryController(InventoryService inventoryService) {
        this.inventoryService = inventoryService;
    }

    @GetMapping("/api/inventory")
    public List<InventoryItemResponse> getAllStockItems() {
        return inventoryService.getAllStockItems();
    }

    @GetMapping("/api/inventory/{productId}")
    public InventoryItemResponse getStockItemByProductId(@PathVariable("productId") Long productId) {
        return inventoryService.getStockItemByProductId(productId);
    }

    @PostMapping("/api/inventory/reservations")
    @ResponseStatus(HttpStatus.CREATED)
    public ReserveStockResponse reserveStock(@RequestBody ReserveStockRequest request) {
        return inventoryService.reserveStock(request);
    }
}
