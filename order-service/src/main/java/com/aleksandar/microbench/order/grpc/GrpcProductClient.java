package com.aleksandar.microbench.order.grpc;

import com.aleksandar.microbench.order.client.ProductClient;
import com.aleksandar.microbench.order.client.ProductResponse;
import com.aleksandar.microbench.order.exception.ProductNotAvailableException;
import com.aleksandar.microbench.product.grpc.GetProductByIdRequestGrpc;
import com.aleksandar.microbench.product.grpc.ProductLookupServiceGrpc;
import com.aleksandar.microbench.product.grpc.ProductResponseGrpc;
import io.grpc.StatusRuntimeException;
import net.devh.boot.grpc.client.inject.GrpcClient;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

@Component
@ConditionalOnProperty(name = "communication.product", havingValue = "grpc")
public class GrpcProductClient implements ProductClient {

    @GrpcClient("product-service")
    private ProductLookupServiceGrpc.ProductLookupServiceBlockingStub productStub;

    @Override
    public ProductResponse getProductById(Long productId) {
        try {
            ProductResponseGrpc response = productStub.getProductById(
                    GetProductByIdRequestGrpc.newBuilder()
                            .setProductId(productId)
                            .build());

            return new ProductResponse(
                    response.getId(),
                    response.getName(),
                    response.getCategory(),
                    new BigDecimal(response.getPrice()));
        } catch (StatusRuntimeException ex) {
            throw new ProductNotAvailableException(productId);
        }
    }
}
