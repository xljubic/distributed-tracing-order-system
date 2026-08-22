package com.aleksandar.microbench.order.supplementary;

import java.math.BigDecimal;

import org.springframework.stereotype.Component;

import com.aleksandar.microbench.literature.grpc.LiteratureProductLookupServiceGrpc;
import com.aleksandar.microbench.literature.grpc.LiteratureProductRequest;
import net.devh.boot.grpc.client.inject.GrpcClient;

@Component("literatureGrpcClient")
public class LiteratureGrpcClient implements LiteratureBenchmarkClient {

    @GrpcClient("product-service")
    private LiteratureProductLookupServiceGrpc.LiteratureProductLookupServiceBlockingStub productStub;

    @Override
    public LiteratureFlatProductResponse getFlat(String payloadSize) {
        var response = productStub.getFlatProduct(request(payloadSize));
        return new LiteratureFlatProductResponse(
                response.getId(), response.getName(), response.getCategory(),
                new BigDecimal(response.getPrice()), response.getPayload());
    }

    @Override
    public LiteratureNestedProductResponse getNested(String payloadSize) {
        var response = productStub.getNestedProduct(request(payloadSize));
        return new LiteratureNestedProductResponse(
                new LiteratureNestedProductResponse.Product(
                        response.getProduct().getId(), response.getProduct().getName(),
                        response.getProduct().getCategory(), new BigDecimal(response.getProduct().getPrice())),
                new LiteratureNestedProductResponse.Payload(
                        response.getPayload().getSize(), response.getPayload().getData()));
    }

    private LiteratureProductRequest request(String payloadSize) {
        return LiteratureProductRequest.newBuilder().setProductId(1).setPayloadSize(payloadSize).build();
    }
}