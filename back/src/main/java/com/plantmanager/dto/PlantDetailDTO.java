package com.plantmanager.dto;

import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.entity.enums.Exposure;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Detailed plant DTO including full species info and recent care logs.
 */
public record PlantDetailDTO(
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
                // Room info
                RoomInfo room,
                // Full species info
                SpeciesInfo species,
                // Custom species name
                String customSpecies,
                // Pot diameter
                BigDecimal potDiameterCm,
                // Recent care logs
                List<CareLogInfo> recentCareLogs) {
        public record RoomInfo(UUID id, String name, String type) {
        }


        public record SpeciesInfo(
                        UUID id,
                        Integer trefleId,
                        String commonName,
                        String scientificName,
                        String family,
                        String genus,
                        String imageUrl) {
        }

        public record CareLogInfo(
                        UUID id,
                        String action,
                        String notes,
                        OffsetDateTime performedAt,
                        String performedByName) {
        }

        /**
         * Create a PlantDetailDTO from a UserPlantEntity.
         */
        public static PlantDetailDTO from(UserPlantEntity entity, String photoBaseUrl) {
                String photoUrl = null;
                if (entity.photoPath != null && !entity.photoPath.isEmpty()) {
                        // Don't add prefix if it's already an absolute URL
                        if (entity.photoPath.startsWith("http://") || entity.photoPath.startsWith("https://")) {
                                photoUrl = entity.photoPath;
                        } else {
                                photoUrl = photoBaseUrl + "/" + entity.photoPath;
                        }
                }

                RoomInfo roomInfo = null;
                if (entity.room != null) {
                        roomInfo = new RoomInfo(
                                        entity.room.id,
                                        entity.room.name,
                                        entity.room.type != null ? entity.room.type.name() : null);
                }

                SpeciesInfo speciesInfo = null;
                if (entity.species != null) {
                        speciesInfo = new SpeciesInfo(
                                        entity.species.id,
                                        entity.species.trefleId,
                                        entity.species.commonName,
                                        entity.species.scientificName,
                                        entity.species.family,
                                        entity.species.genus,
                                        entity.species.imageUrl);
                }

                // Get last 5 care logs
                List<CareLogInfo> careLogs = entity.careLogs.stream()
                                .sorted((a, b) -> b.performedAt.compareTo(a.performedAt))
                                .limit(5)
                                .map(log -> new CareLogInfo(
                                                log.id,
                                                log.action.name(),
                                                log.notes,
                                                log.performedAt,
                                                log.user != null ? log.user.displayName : null))
                                .toList();

                return new PlantDetailDTO(
                                entity.id,
                                entity.nickname,
                                photoUrl,
                                entity.acquiredAt,
                                entity.lastWatered,
                                entity.wateringIntervalDays,
                                entity.getNextWateringDate(),
                                entity.needsWatering(),
                                entity.notes,
                                entity.isSick,
                                entity.isWilted,
                                entity.needsRepotting,
                                entity.exposure,
                                entity.createdAt,
                                roomInfo,
                                speciesInfo,
                                entity.customSpecies,
                                entity.potDiameterCm,
                                careLogs);
        }

        public static PlantDetailDTO from(UserPlantEntity entity) {
                return from(entity, "/api/v1/files");
        }
}
