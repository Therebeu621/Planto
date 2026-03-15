package com.plantmanager.dto.weather;

import java.util.List;

/**
 * DTO for weather-based watering advice.
 * Combines current weather data with intelligent watering recommendations.
 */
public record WeatherWateringAdviceDTO(
        /** City name */
        String city,

        /** Current temperature in Celsius */
        double temperature,

        /** Current humidity percentage */
        int humidity,

        /** Weather description (e.g., "pluie légère") */
        String weatherDescription,

        /** Rain amount in mm */
        double rainMm,

        /** Whether outdoor plants should skip watering */
        boolean shouldSkipOutdoorWatering,

        /** Whether indoor watering interval should be adjusted */
        String indoorAdvice,

        /** Adjustment factor for watering interval (1.0 = no change, 0.5 = water twice as often) */
        double intervalAdjustmentFactor,

        /** Human-readable advice list */
        List<String> advices
) {
}
