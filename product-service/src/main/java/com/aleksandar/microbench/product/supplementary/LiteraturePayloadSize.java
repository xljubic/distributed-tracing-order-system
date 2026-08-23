package com.aleksandar.microbench.product.supplementary;

import java.util.Locale;

public enum LiteraturePayloadSize {

    SMALL(128),
    MEDIUM(4096),
    LARGE(65536),

    SMALL_1KB(1024),
    LARGE_875KB(896000),

    HAMO_SMALL(14),
    HAMO_MEDIUM(153600),
    HAMO_LARGE(3145728);

    private final int characters;

    LiteraturePayloadSize(int characters) {
        this.characters = characters;
    }

    public int characters() {
        return characters;
    }

    public static LiteraturePayloadSize parse(String value) {
        try {
            return valueOf(
                value
                    .replace('-', '_')
                    .toUpperCase(Locale.ROOT)
            );
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException(
                "Unsupported payload size: " + value,
                ex
            );
        }
    }
}