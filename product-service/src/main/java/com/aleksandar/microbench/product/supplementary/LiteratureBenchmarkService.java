package com.aleksandar.microbench.product.supplementary;

import org.springframework.stereotype.Service;

import com.aleksandar.microbench.product.dto.ProductResponse;
import com.aleksandar.microbench.product.service.ProductService;

@Service
public class LiteratureBenchmarkService {

    private static final String PAYLOAD_PATTERN = "literature-benchmark-payload-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    private final ProductService productService;

    public LiteratureBenchmarkService(ProductService productService) {
        this.productService = productService;
    }

    public LiteratureProductResponse getFlat(Long productId, LiteraturePayloadSize payloadSize) {
        ProductResponse product = productService.getProductById(productId);
        return new LiteratureProductResponse(
                product.id(), product.name(), product.category(), product.price(), payload(payloadSize));
    }

    public LiteratureNestedProductResponse getNested(Long productId, LiteraturePayloadSize payloadSize) {
        LiteratureProductResponse flat = getFlat(productId, payloadSize);
        return new LiteratureNestedProductResponse(
                new LiteratureNestedProductResponse.Product(flat.id(), flat.name(), flat.category(), flat.price()),
                new LiteratureNestedProductResponse.Payload(payloadSize.name().toLowerCase(), flat.payload()));
    }

    private String payload(LiteraturePayloadSize payloadSize) {
        StringBuilder result = new StringBuilder(payloadSize.characters());
        while (result.length() < payloadSize.characters()) {
            result.append(PAYLOAD_PATTERN);
        }
        return result.substring(0, payloadSize.characters());
    }
}