package com.plantmanager.dto;

import com.plantmanager.entity.PotStockEntity;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for pot stock responses.
 */
public record PotStockDTO(
        UUID id,
        BigDecimal diameterCm,
        int quantity,
        String label,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt) {

    public static PotStockDTO from(PotStockEntity entity) {
        return new PotStockDTO(
                entity.id,
                entity.diameterCm,
                entity.quantity,
                entity.label,
                entity.createdAt,
                entity.updatedAt);
    }
}
