package com.plantmanager.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.jboss.logging.Logger;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Service for plant data from local JSON database.
 * Provides search and lookup functionality for 300 indoor plants.
 */
@ApplicationScoped
public class PlantDatabaseService {

    private static final Logger LOG = Logger.getLogger(PlantDatabaseService.class);
    private static final String DATABASE_FILE = "/plants-database.json";

    @Inject
    ObjectMapper objectMapper;

    private List<PlantData> plants = new ArrayList<>();

    /**
     * Plant data record.
     */
    public static class PlantData {
        public String nomFrancais;
        public String nomLatin;
        public int arrosageFrequenceJours;
        public String luminosite;

        public PlantData() {
        }

        public PlantData(String nomFrancais, String nomLatin, int arrosageFrequenceJours, String luminosite) {
            this.nomFrancais = nomFrancais;
            this.nomLatin = nomLatin;
            this.arrosageFrequenceJours = arrosageFrequenceJours;
            this.luminosite = luminosite;
        }
    }

    /**
     * Load plant database on startup.
     */
    @PostConstruct
    void loadDatabase() {
        try (InputStream is = getClass().getResourceAsStream(DATABASE_FILE)) {
            if (is == null) {
                LOG.error("Plant database file not found: " + DATABASE_FILE);
                return;
            }

            JsonNode root = objectMapper.readTree(is);
            JsonNode plantesArray = root.get("plantes");

            if (plantesArray != null && plantesArray.isArray()) {
                for (JsonNode node : plantesArray) {
                    PlantData plant = new PlantData(
                            node.get("nomFrancais").asText(),
                            node.get("nomLatin").asText(),
                            node.get("arrosageFrequenceJours").asInt(),
                            node.get("luminosite").asText());
                    plants.add(plant);
                }
            }

            LOG.infof("Loaded %d plants from database", plants.size());

        } catch (Exception e) {
            LOG.errorf("Error loading plant database: %s", e.getMessage());
        }
    }

    /**
     * Search plants by name (French or Latin).
     * Returns up to 10 matching results.
     *
     * @param query Search query (min 2 characters)
     * @return List of matching plants
     */
    public List<PlantData> search(String query) {
        if (query == null || query.trim().length() < 2) {
            return List.of();
        }

        String lowerQuery = query.toLowerCase().trim();
        List<PlantData> results = new ArrayList<>();

        for (PlantData plant : plants) {
            // Check if French name or Latin name contains the query
            boolean matchesFrench = plant.nomFrancais.toLowerCase().contains(lowerQuery);
            boolean matchesLatin = plant.nomLatin.toLowerCase().contains(lowerQuery);

            if (matchesFrench || matchesLatin) {
                results.add(plant);
                if (results.size() >= 10) {
                    break;
                }
            }
        }

        // Sort: exact matches first, then starts-with, then contains
        results.sort((a, b) -> {
            int scoreA = getMatchScore(a, lowerQuery);
            int scoreB = getMatchScore(b, lowerQuery);
            return scoreB - scoreA; // Higher score first
        });

        LOG.debugf("Search '%s' returned %d results", query, results.size());
        return results;
    }

    /**
     * Get a plant by exact French name.
     */
    public PlantData getByName(String name) {
        if (name == null)
            return null;

        String lowerName = name.toLowerCase().trim();
        return plants.stream()
                .filter(p -> p.nomFrancais.toLowerCase().equals(lowerName))
                .findFirst()
                .orElse(null);
    }

    /**
     * Get match score for sorting (higher = better match).
     */
    private int getMatchScore(PlantData plant, String query) {
        String frenchLower = plant.nomFrancais.toLowerCase();
        String latinLower = plant.nomLatin.toLowerCase();

        // Exact match
        if (frenchLower.equals(query) || latinLower.equals(query)) {
            return 100;
        }
        // Starts with query
        if (frenchLower.startsWith(query) || latinLower.startsWith(query)) {
            return 50;
        }
        // Contains query
        return 10;
    }

    /**
     * Get total number of plants in database.
     */
    public int getPlantCount() {
        return plants.size();
    }
}
