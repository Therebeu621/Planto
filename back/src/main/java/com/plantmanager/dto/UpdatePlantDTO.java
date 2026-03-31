package com.plantmanager.dto;

import com.plantmanager.entity.enums.Exposure;
import com.plantmanager.entity.enums.HealthStatus;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * DTO for updating an existing plant.
 * All fields are optional - only provided fields will be updated.
 */
public record UpdatePlantDTO(
        /** New room ID to move plant to */
        UUID roomId,

        /** New nickname for the plant */
        @Size(max = 100, message = "Nickname must be at most 100 characters") String nickname,

        /** Updated notes */
        String notes,

        /** Updated photo path */
        String photoPath,

        /** Updated watering interval */
        @Min(value = 1, message = "Watering interval must be at least 1 day") @Max(value = 365, message = "Watering interval must be at most 365 days") Integer wateringIntervalDays,

        /** Updated health status */
        HealthStatus healthStatus,

        /** Updated exposure requirement */
        Exposure exposure,

        /** Plant is sick */
        Boolean isSick,

        /** Plant is wilted */
        Boolean isWilted,

        /** Plant needs repotting */
        Boolean needsRepotting,

        /** If true, mark the plant as watered now */
        Boolean markAsWatered,

        /** Pot diameter in cm */
        @DecimalMin(value = "0.1", message = "Le diametre du pot doit etre superieur a 0")
        @DecimalMax(value = "200.0", message = "Le diametre du pot doit etre inferieur ou egal a 200 cm")
        BigDecimal potDiameterCm) {
}
