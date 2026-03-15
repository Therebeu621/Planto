package com.plantmanager.dto.perenual;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Response from Perenual /species/details/{id} endpoint.
 * Contains detailed care information.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class PerenualDetailsResponse {

    @JsonProperty("id")
    public int id;

    @JsonProperty("common_name")
    public String commonName;

    @JsonProperty("scientific_name")
    public List<String> scientificName;

    @JsonProperty("cycle")
    public String cycle;

    @JsonProperty("watering")
    public String watering;

    @JsonProperty("watering_general_benchmark")
    public WateringBenchmark wateringBenchmark;

    @JsonProperty("sunlight")
    public List<String> sunlight;

    @JsonProperty("care_level")
    public String careLevel;

    @JsonProperty("description")
    public String description;

    @JsonProperty("default_image")
    public DefaultImage defaultImage;

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class WateringBenchmark {
        @JsonProperty("value")
        public String value; // e.g., "7-10"

        @JsonProperty("unit")
        public String unit; // e.g., "days"
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class DefaultImage {
        @JsonProperty("thumbnail")
        public String thumbnail;

        @JsonProperty("regular_url")
        public String regularUrl;

        @JsonProperty("original_url")
        public String originalUrl;
    }

    /**
     * Calculate recommended watering interval in days.
     */
    public int getRecommendedIntervalDays() {
        // First try benchmark
        if (wateringBenchmark != null && wateringBenchmark.value != null) {
            try {
                // Parse "7-10" -> take average
                if (wateringBenchmark.value.contains("-")) {
                    String[] parts = wateringBenchmark.value.split("-");
                    int min = Integer.parseInt(parts[0].trim());
                    int max = Integer.parseInt(parts[1].trim());
                    return (min + max) / 2;
                }
                return Integer.parseInt(wateringBenchmark.value.trim());
            } catch (NumberFormatException ignored) {
                // Fall through to watering frequency fallback below
            }
        }

        // Fallback to watering frequency string
        if (watering != null) {
            return switch (watering.toLowerCase()) {
                case "frequent" -> 3;
                case "average" -> 7;
                case "minimum" -> 14;
                case "none" -> 30;
                default -> 7;
            };
        }

        return 7; // Default
    }
}
