package com.aleksandar.microbench.product.grpc;

import com.aleksandar.microbench.product.dto.ProductResponse;
import com.aleksandar.microbench.product.service.ProductService;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import net.devh.boot.grpc.server.service.GrpcService;

@GrpcService
public class ProductGrpcService extends ProductLookupServiceGrpc.ProductLookupServiceImplBase {

    private final ProductService productService;

    public ProductGrpcService(ProductService productService) {
        this.productService = productService;
    }

    @Override
    public void getProductById(
            GetProductByIdRequestGrpc request,
            StreamObserver<ProductResponseGrpc> responseObserver) {
        try {
            ProductResponse response = productService.getProductById(request.getProductId());

            responseObserver.onNext(ProductResponseGrpc.newBuilder()
                    .setId(response.id())
                    .setName(response.name())
                    .setCategory(response.category())
                    .setPrice(response.price().toPlainString())
                    .build());
            responseObserver.onCompleted();
        } catch (RuntimeException ex) {
            responseObserver.onError(Status.NOT_FOUND
                    .withDescription(ex.getMessage())
                    .asRuntimeException());
        }
    }
}
