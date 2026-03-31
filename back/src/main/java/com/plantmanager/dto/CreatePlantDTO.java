package com.plantmanager.dto;

import com.plantmanager.entity.enums.Exposure;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for creating a new plant.
 */
public record CreatePlantDTO(
        /** Optional species ID from species cache */
        UUID speciesId,

        /** Optional room ID to assign plant to */
        UUID roomId,

        /** Nickname for the plant (required) */
        @NotBlank(message = "Le petit nom est requis") @Size(max = 100, message = "Le petit nom doit contenir au maximum 100 caracteres") String nickname,

        /** Watering interval in days (default: 7) */
        @Min(value = 1, message = "L'intervalle d'arrosage doit etre compris entre 1 et 365 jours") @Max(value = 365, message = "L'intervalle d'arrosage doit etre compris entre 1 et 365 jours") Integer wateringIntervalDays,

        /** Optional notes about the plant */
        String notes,

        /** Light exposure requirement (default: PARTIAL_SHADE) */
        Exposure exposure,

        /** Optional photo URL for the plant */
        String photoUrl,

        /** Custom species name (when not selecting from database) */
        String customSpecies,

        /** Last watered date (optional, for calculating next watering) */
        OffsetDateTime lastWatered,

        /** Health flags */
        Boolean isSick,
        Boolean isWilted,
        Boolean needsRepotting,

        /** Pot diameter in cm */
        @DecimalMin(value = "0.1", message = "Le diametre du pot doit etre superieur a 0")
        @DecimalMax(value = "200.0", message = "Le diametre du pot doit etre inferieur ou egal a 200 cm")
        BigDecimal potDiameterCm) {
    /**
     * Return watering interval or default.
     */
    public int getWateringIntervalOrDefault() {
        return wateringIntervalDays != null ? wateringIntervalDays : 7;
    }

    /**
     * Return exposure or default.
     */
    public Exposure getExposureOrDefault() {
        return exposure != null ? exposure : Exposure.PARTIAL_SHADE;
    }
}
