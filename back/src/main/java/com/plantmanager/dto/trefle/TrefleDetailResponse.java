package com.plantmanager.dto.trefle;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Response from Trefle.io plant detail endpoint.
 * GET /plants/{id}
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class TrefleDetailResponse {

    private TreflePlantDetail data;

    public TreflePlantDetail getData() {
        return data;
    }

    public void setData(TreflePlantDetail data) {
        this.data = data;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class TreflePlantDetail {

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

        private String bibliography;

        @JsonProperty("family_common_name")
        private String familyCommonName;

        @JsonProperty("main_species")
        private MainSpecies mainSpecies;

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

        public String getBibliography() {
            return bibliography;
        }

        public void setBibliography(String bibliography) {
            this.bibliography = bibliography;
        }

        public String getFamilyCommonName() {
            return familyCommonName;
        }

        public void setFamilyCommonName(String familyCommonName) {
            this.familyCommonName = familyCommonName;
        }

        public MainSpecies getMainSpecies() {
            return mainSpecies;
        }

        public void setMainSpecies(MainSpecies mainSpecies) {
            this.mainSpecies = mainSpecies;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class MainSpecies {
        private String slug;

        @JsonProperty("common_name")
        private String commonName;

        @JsonProperty("scientific_name")
        private String scientificName;

        public String getSlug() {
            return slug;
        }

        public void setSlug(String slug) {
            this.slug = slug;
        }

        public String getCommonName() {
            return commonName;
        }

        public void setCommonName(String commonName) {
            this.commonName = commonName;
        }

        public String getScientificName() {
            return scientificName;
        }

        public void setScientificName(String scientificName) {
            this.scientificName = scientificName;
        }
    }
}
