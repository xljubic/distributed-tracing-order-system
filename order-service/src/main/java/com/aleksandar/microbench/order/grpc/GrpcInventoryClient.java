package com.aleksandar.microbench.order.grpc;

import com.aleksandar.microbench.inventory.grpc.InventoryReservationServiceGrpc;
import com.aleksandar.microbench.inventory.grpc.ReserveStockItemGrpc;
import com.aleksandar.microbench.inventory.grpc.ReserveStockRequestGrpc;
import com.aleksandar.microbench.inventory.grpc.ReserveStockResponseGrpc;
import com.aleksandar.microbench.order.client.InventoryClient;
import com.aleksandar.microbench.order.client.ReserveStockRequest;
import com.aleksandar.microbench.order.client.ReserveStockResponse;
import com.aleksandar.microbench.order.client.ReservedStockItemResponse;
import net.devh.boot.grpc.client.inject.GrpcClient;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        name = "communication.inventory",
        havingValue = "grpc"
)
public class GrpcInventoryClient implements InventoryClient {

    @GrpcClient("inventory-service")
    private InventoryReservationServiceGrpc.InventoryReservationServiceBlockingStub inventoryStub;

    @Override
    public ReserveStockResponse reserveStock(ReserveStockRequest request) {
        ReserveStockRequestGrpc grpcRequest = ReserveStockRequestGrpc.newBuilder()
                .addAllItems(
                        request.items()
                                .stream()
                                .map(item -> ReserveStockItemGrpc.newBuilder()
                                        .setProductId(item.productId())
                                        .setQuantity(item.quantity())
                                        .build())
                                .toList()
                )
                .build();

        ReserveStockResponseGrpc grpcResponse = inventoryStub.reserveStock(grpcRequest);

        return new ReserveStockResponse(
                grpcResponse.getStatus(),
                grpcResponse.getItemsList()
                        .stream()
                        .map(item -> new ReservedStockItemResponse(
                                item.getProductId(),
                                item.getQuantity(),
                                item.getStatus()))
                        .toList());
    }
}
