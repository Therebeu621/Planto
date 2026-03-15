package com.plantmanager.dto.perenual;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Response from Perenual /species-list endpoint.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class PerenualSearchResponse {

    @JsonProperty("data")
    public List<PerenualSpecies> data;

    @JsonProperty("to")
    public int to;

    @JsonProperty("total")
    public int total;

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class PerenualSpecies {
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

        @JsonProperty("sunlight")
        public List<String> sunlight;

        @JsonProperty("default_image")
        public DefaultImage defaultImage;

        @JsonIgnoreProperties(ignoreUnknown = true)
        public static class DefaultImage {
            @JsonProperty("thumbnail")
            public String thumbnail;

            @JsonProperty("regular_url")
            public String regularUrl;
        }
    }
}
