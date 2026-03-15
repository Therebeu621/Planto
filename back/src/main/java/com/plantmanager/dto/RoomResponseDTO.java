package com.plantmanager.dto;

import com.plantmanager.entity.RoomEntity;
import com.plantmanager.entity.enums.RoomType;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * DTO for room response with nested plants.
 * Avoids infinite JSON loops by using PlantResponseDTO (no back-reference to
 * room).
 */
public record RoomResponseDTO(
                UUID id,
                String name,
                RoomType type,
                int plantCount,
                OffsetDateTime createdAt,
                List<PlantSummaryDTO> plants) {
        /**
         * Simplified plant DTO for nested display (no room back-reference).
         */
        public record PlantSummaryDTO(
                        UUID id,
                        String nickname,
                        String photoUrl,
                        String speciesCommonName,
                        boolean needsWatering,
                        LocalDate nextWateringDate,
                        boolean isSick,
                        boolean isWilted,
                        boolean needsRepotting) {
        }

        /**
         * Create a RoomResponseDTO from a RoomEntity WITH plants loaded.
         */
        public static RoomResponseDTO from(RoomEntity entity, String photoBaseUrl) {
                List<PlantSummaryDTO> plantDtos = entity.plants.stream()
                                .map(plant -> {
                                        String photoUrl = null;
                                        if (plant.photoPath != null && !plant.photoPath.isEmpty()) {
                                                if (plant.photoPath.startsWith("http://")
                                                                || plant.photoPath.startsWith("https://")) {
                                                        photoUrl = plant.photoPath;
                                                } else {
                                                        photoUrl = photoBaseUrl + "/" + plant.photoPath;
                                                }
                                        }
                                        // Calculate needsWatering based on nextWateringDate
                                        boolean needsWater = plant.nextWateringDate != null
                                                        ? !plant.nextWateringDate.isAfter(java.time.LocalDate.now())
                                                        : plant.needsWatering();
                                        return new PlantSummaryDTO(
                                                        plant.id,
                                                        plant.nickname,
                                                        photoUrl,
                                                        plant.species != null ? plant.species.commonName : null,
                                                        needsWater,
                                                        plant.nextWateringDate,
                                                        plant.isSick,
                                                        plant.isWilted,
                                                        plant.needsRepotting);
                                })
                                .toList();

                return new RoomResponseDTO(
                                entity.id,
                                entity.name,
                                entity.type,
                                plantDtos.size(),
                                entity.createdAt,
                                plantDtos);
        }

        /**
         * Create a RoomResponseDTO without loading plants (for list views).
         */
        public static RoomResponseDTO fromWithoutPlants(RoomEntity entity) {
                return new RoomResponseDTO(
                                entity.id,
                                entity.name,
                                entity.type,
                                entity.plants != null ? entity.plants.size() : 0,
                                entity.createdAt,
                                List.of());
        }
}
