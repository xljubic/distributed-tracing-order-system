package com.aleksandar.microbench.product.supplementary;

import com.aleksandar.microbench.literature.grpc.LiteratureFlatProductResponse;
import com.aleksandar.microbench.literature.grpc.LiteraturePayload;
import com.aleksandar.microbench.literature.grpc.LiteratureProduct;
import com.aleksandar.microbench.literature.grpc.LiteratureProductLookupServiceGrpc;
import com.aleksandar.microbench.literature.grpc.LiteratureProductRequest;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import net.devh.boot.grpc.server.service.GrpcService;

@GrpcService
public class LiteratureBenchmarkGrpcService
        extends LiteratureProductLookupServiceGrpc.LiteratureProductLookupServiceImplBase {

    private final LiteratureBenchmarkService benchmarkService;

    public LiteratureBenchmarkGrpcService(LiteratureBenchmarkService benchmarkService) {
        this.benchmarkService = benchmarkService;
    }

    @Override
    public void getFlatProduct(LiteratureProductRequest request,
            StreamObserver<LiteratureFlatProductResponse> observer) {
        try {
            LiteratureProductResponse response = benchmarkService.getFlat(
                    request.getProductId(), LiteraturePayloadSize.parse(request.getPayloadSize()));
            observer.onNext(LiteratureFlatProductResponse.newBuilder()
                    .setId(response.id()).setName(response.name()).setCategory(response.category())
                    .setPrice(response.price().toPlainString()).setPayload(response.payload()).build());
            observer.onCompleted();
        } catch (RuntimeException ex) {
            observer.onError(Status.INVALID_ARGUMENT.withDescription(ex.getMessage()).asRuntimeException());
        }
    }

    @Override
    public void getNestedProduct(LiteratureProductRequest request,
            StreamObserver<com.aleksandar.microbench.literature.grpc.LiteratureNestedProductResponse> observer) {
        try {
            LiteratureNestedProductResponse response = benchmarkService.getNested(
                    request.getProductId(), LiteraturePayloadSize.parse(request.getPayloadSize()));
            observer.onNext(com.aleksandar.microbench.literature.grpc.LiteratureNestedProductResponse.newBuilder()
                    .setProduct(LiteratureProduct.newBuilder()
                            .setId(response.product().id()).setName(response.product().name())
                            .setCategory(response.product().category())
                            .setPrice(response.product().price().toPlainString()).build())
                    .setPayload(LiteraturePayload.newBuilder()
                            .setSize(response.payload().size()).setData(response.payload().data()).build())
                    .build());
            observer.onCompleted();
        } catch (RuntimeException ex) {
            observer.onError(Status.INVALID_ARGUMENT.withDescription(ex.getMessage()).asRuntimeException());
        }
    }
}