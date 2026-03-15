package com.plantmanager.dto;

import java.util.List;

/**
 * DTO for care recommendation response.
 * Sent to frontend when species is selected.
 */
public record CareRecommendationDTO(
        /** Watering frequency: "Frequent", "Average", "Minimum" */
        String wateringFrequency,

        /** Recommended watering interval in days */
        int recommendedIntervalDays,

        /** Sunlight requirements */
        List<String> sunlight,

        /** Care level: "Easy", "Medium", "Hard" */
        String careLevel,

        /** Human-readable care description */
        String description,

        /** Plant image URL */
        String imageUrl) {

    private static final String DEFAULT_LEVEL = "Moyen";

    /**
     * Create from Perenual details response.
     */
    public static CareRecommendationDTO from(
            com.plantmanager.dto.perenual.PerenualDetailsResponse details) {
        return new CareRecommendationDTO(
                details.watering,
                details.getRecommendedIntervalDays(),
                details.sunlight,
                details.careLevel,
                details.description,
                details.defaultImage != null ? details.defaultImage.regularUrl : null);
    }

    /**
     * Get a recommendation message for the user.
     */
    public String getRecommendationMessage() {
        StringBuilder msg = new StringBuilder();

        if (wateringFrequency != null) {
            msg.append("Arrosage: ").append(getWateringFrench()).append(" (tous les ")
                    .append(recommendedIntervalDays).append(" jours). ");
        }

        if (sunlight != null && !sunlight.isEmpty()) {
            msg.append("Exposition: ").append(String.join(", ", sunlight)).append(". ");
        }

        if (careLevel != null) {
            msg.append("Niveau de soin: ").append(getCareLevelFrench()).append(".");
        }

        return msg.toString();
    }

    private String getWateringFrench() {
        if (wateringFrequency == null)
            return DEFAULT_LEVEL;
        return switch (wateringFrequency.toLowerCase()) {
            case "frequent" -> "Fréquent";
            case "average" -> DEFAULT_LEVEL;
            case "minimum" -> "Peu fréquent";
            case "none" -> "Très rare";
            default -> wateringFrequency;
        };
    }

    private String getCareLevelFrench() {
        if (careLevel == null)
            return DEFAULT_LEVEL;
        return switch (careLevel.toLowerCase()) {
            case "low" -> "Facile";
            case "medium" -> DEFAULT_LEVEL;
            case "high" -> "Difficile";
            default -> careLevel;
        };
    }
}
