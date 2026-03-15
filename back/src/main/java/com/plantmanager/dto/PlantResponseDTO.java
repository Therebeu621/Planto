package com.plantmanager.dto;

import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.entity.enums.Exposure;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for plant response (list/detail views).
 */
public record PlantResponseDTO(
        UUID id,
        String nickname,
        String photoUrl,
        LocalDate acquiredAt,
        OffsetDateTime lastWatered,
        Integer wateringIntervalDays,
        LocalDate nextWateringDate,
        boolean needsWatering,
        String notes,
        boolean isSick,
        boolean isWilted,
        boolean needsRepotting,
        Exposure exposure,
        OffsetDateTime createdAt,
        // Denormalized data
        UUID roomId,
        String roomName,
        UUID speciesId,
        String speciesCommonName,
        String speciesScientificName,
        String speciesImageUrl,
        String customSpecies,
        BigDecimal potDiameterCm) {
    /**
     * Create a PlantResponseDTO from a UserPlantEntity.
     * Assumes associations are loaded.
     *
     * @param entity       the plant entity
     * @param photoBaseUrl base URL for photo path conversion
     * @return PlantResponseDTO with all data
     */
    public static PlantResponseDTO from(UserPlantEntity entity, String photoBaseUrl) {
        String photoUrl = null;
        if (entity.photoPath != null && !entity.photoPath.isEmpty()) {
            // Don't add prefix if it's already an absolute URL
            if (entity.photoPath.startsWith("http://") || entity.photoPath.startsWith("https://")) {
                photoUrl = entity.photoPath;
            } else {
                photoUrl = photoBaseUrl + "/" + entity.photoPath;
            }
        }

        return new PlantResponseDTO(
                entity.id,
                entity.nickname,
                photoUrl,
                entity.acquiredAt,
                entity.lastWatered,
                entity.wateringIntervalDays,
                entity.nextWateringDate, // Use persisted field for fast access
                entity.nextWateringDate != null && !entity.nextWateringDate.isAfter(LocalDate.now()),
                entity.notes,
                entity.isSick,
                entity.isWilted,
                entity.needsRepotting,
                entity.exposure,
                entity.createdAt,
                // Room info
                entity.room != null ? entity.room.id : null,
                entity.room != null ? entity.room.name : null,
                // Species info
                entity.species != null ? entity.species.id : null,
                entity.species != null ? entity.species.commonName : null,
                entity.species != null ? entity.species.scientificName : null,
                entity.species != null ? entity.species.imageUrl : null,
                entity.customSpecies,
                entity.potDiameterCm);
    }

    /**
     * Create a PlantResponseDTO from a UserPlantEntity with default photo base URL.
     */
    public static PlantResponseDTO from(UserPlantEntity entity) {
        return from(entity, "/api/v1/files");
    }
}
