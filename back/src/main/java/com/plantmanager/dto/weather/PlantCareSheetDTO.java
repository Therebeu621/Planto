package com.plantmanager.dto.weather;

import java.util.List;

/**
 * DTO for enriched plant care sheet.
 * Generated/enriched via MCP with comprehensive care information.
 */
public record PlantCareSheetDTO(
        /** Plant species name */
        String speciesName,

        /** Scientific name if known */
        String scientificName,

        /** Plant category (tropical, succulent, flowering, herb, general) */
        String category,

        /** Watering frequency description */
        String wateringFrequency,

        /** Recommended watering interval in days */
        int wateringIntervalDays,

        /** Sunlight requirements */
        List<String> sunlight,

        /** Care difficulty level */
        String careLevel,

        /** Detailed watering tip */
        String wateringTip,

        /** Seasonal care adjustments */
        List<SeasonalAdvice> seasonalAdvice,

        /** Common problems and solutions */
        List<String> commonProblems,

        /** Weather-based current advice (if weather data available) */
        String weatherAdvice,

        /** Overall care summary in French */
        String careSummary
) {

    public record SeasonalAdvice(
            String season,
            String wateringAdjustment,
            String careNotes
    ) {
    }
}
