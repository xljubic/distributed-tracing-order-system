package com.aleksandar.microbench.inventory.grpc;

import com.aleksandar.microbench.inventory.dto.ReserveStockItemRequest;
import com.aleksandar.microbench.inventory.dto.ReserveStockRequest;
import com.aleksandar.microbench.inventory.dto.ReserveStockResponse;
import com.aleksandar.microbench.inventory.service.InventoryService;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import net.devh.boot.grpc.server.service.GrpcService;

@GrpcService
public class InventoryGrpcService extends InventoryReservationServiceGrpc.InventoryReservationServiceImplBase {

    private final InventoryService inventoryService;

    public InventoryGrpcService(InventoryService inventoryService) {
        this.inventoryService = inventoryService;
    }

    @Override
    public void reserveStock(
            ReserveStockRequestGrpc request,
            StreamObserver<ReserveStockResponseGrpc> responseObserver
    ) {
        try {
            ReserveStockRequest reserveStockRequest = new ReserveStockRequest(
                    request.getItemsList()
                            .stream()
                            .map(item -> new ReserveStockItemRequest(
                                    item.getProductId(),
                                    item.getQuantity()
                            ))
                            .toList()
            );

            ReserveStockResponse response = inventoryService.reserveStock(reserveStockRequest);

            responseObserver.onNext(
                    ReserveStockResponseGrpc.newBuilder()
                            .setStatus(response.status())
                            .build()
            );
            responseObserver.onCompleted();

        } catch (RuntimeException ex) {
            responseObserver.onError(
                    Status.FAILED_PRECONDITION
                            .withDescription(ex.getMessage())
                            .asRuntimeException()
            );
        }
    }
}