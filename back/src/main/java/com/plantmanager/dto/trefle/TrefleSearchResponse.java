package com.plantmanager.dto.trefle;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Response from Trefle.io search endpoint.
 * GET /plants/search?q=xxx
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class TrefleSearchResponse {

    private List<TreflePlantSummary> data;

    private Meta meta;

    public List<TreflePlantSummary> getData() {
        return data;
    }

    public void setData(List<TreflePlantSummary> data) {
        this.data = data;
    }

    public Meta getMeta() {
        return meta;
    }

    public void setMeta(Meta meta) {
        this.meta = meta;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Meta {
        private int total;

        public int getTotal() {
            return total;
        }

        public void setTotal(int total) {
            this.total = total;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class TreflePlantSummary {

        private int id;

        @JsonProperty("common_name")
        private String commonName;

        private String slug;

        @JsonProperty("scientific_name")
        private String scientificName;

        private String family;

        private String genus;

        @JsonProperty("image_url")
        private String imageUrl;

        private int year;

        private String author;

        @JsonProperty("family_common_name")
        private String familyCommonName;

        public int getId() {
            return id;
        }

        public void setId(int id) {
            this.id = id;
        }

        public String getCommonName() {
            return commonName;
        }

        public void setCommonName(String commonName) {
            this.commonName = commonName;
        }

        public String getSlug() {
            return slug;
        }

        public void setSlug(String slug) {
            this.slug = slug;
        }

        public String getScientificName() {
            return scientificName;
        }

        public void setScientificName(String scientificName) {
            this.scientificName = scientificName;
        }

        public String getFamily() {
            return family;
        }

        public void setFamily(String family) {
            this.family = family;
        }

        public String getGenus() {
            return genus;
        }

        public void setGenus(String genus) {
            this.genus = genus;
        }

        public String getImageUrl() {
            return imageUrl;
        }

        public void setImageUrl(String imageUrl) {
            this.imageUrl = imageUrl;
        }

        public int getYear() {
            return year;
        }

        public void setYear(int year) {
            this.year = year;
        }

        public String getAuthor() {
            return author;
        }

        public void setAuthor(String author) {
            this.author = author;
        }

        public String getFamilyCommonName() {
            return familyCommonName;
        }

        public void setFamilyCommonName(String familyCommonName) {
            this.familyCommonName = familyCommonName;
        }
    }
}
