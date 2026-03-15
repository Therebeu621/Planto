package com.plantmanager.dto;

import java.time.OffsetDateTime;

/**
 * DTO for user statistics.
 */
public record UserStatsDTO(
        int totalPlants,
        int wateringsThisMonth,
        int wateringStreak,
        int healthyPlantsPercentage,
        String oldestPlantName,
        OffsetDateTime oldestPlantAcquiredAt) {

    public static UserStatsDTO of(
            int totalPlants,
            int wateringsThisMonth,
            int wateringStreak,
            int healthyPlantsPercentage,
            String oldestPlantName,
            OffsetDateTime oldestPlantAcquiredAt) {
        return new UserStatsDTO(
                totalPlants,
                wateringsThisMonth,
                wateringStreak,
                healthyPlantsPercentage,
                oldestPlantName,
                oldestPlantAcquiredAt);
    }
}
