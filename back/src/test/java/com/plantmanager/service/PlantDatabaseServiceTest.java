package com.plantmanager.service;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@QuarkusTest
public class PlantDatabaseServiceTest {

    @Inject
    PlantDatabaseService plantDatabaseService;

    @Test
    void testLoadDatabase_shouldLoadPlants() {
        int count = plantDatabaseService.getPlantCount();
        assertTrue(count > 0, "Database should contain plants");
        assertEquals(300, count, "Should have 300 plants from seed data");
    }

    @Test
    void testSearch_exactMatch_shouldReturnFirst() {
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search("Monstera deliciosa");
        assertFalse(results.isEmpty());
        // Exact match should be first
        assertEquals("Monstera deliciosa", results.get(0).nomFrancais);
    }

    @Test
    void testSearch_partialMatch_shouldReturnList() {
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search("Ficus");
        assertFalse(results.isEmpty());
        assertTrue(results.stream().anyMatch(p -> p.nomFrancais.contains("Ficus") || p.nomLatin.contains("Ficus")));
    }

    @Test
    void testSearch_caseInsensitive() {
        List<PlantDatabaseService.PlantData> resultsUpper = plantDatabaseService.search("MONSTERA");
        List<PlantDatabaseService.PlantData> resultsLower = plantDatabaseService.search("monstera");

        assertFalse(resultsUpper.isEmpty());
        assertEquals(resultsUpper.size(), resultsLower.size());
    }

    @Test
    void testGetByName_shouldReturnPlant() {
        PlantDatabaseService.PlantData plant = plantDatabaseService.getByName("Monstera deliciosa");
        assertNotNull(plant);
        assertEquals("Monstera deliciosa", plant.nomFrancais);
        assertNotNull(plant.nomLatin);
    }

    @Test
    void testGetByName_notFound_shouldReturnNull() {
        PlantDatabaseService.PlantData plant = plantDatabaseService.getByName("NonExistentPlant");
        assertNull(plant);
    }

    @Test
    void testGetByName_nullName_shouldReturnNull() {
        PlantDatabaseService.PlantData plant = plantDatabaseService.getByName(null);
        assertNull(plant);
    }

    @Test
    void testSearch_nullQuery_shouldReturnEmpty() {
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search(null);
        assertTrue(results.isEmpty());
    }

    @Test
    void testSearch_singleChar_shouldReturnEmpty() {
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search("a");
        assertTrue(results.isEmpty());
    }

    @Test
    void testSearch_maxTenResults() {
        // Use a broad query to potentially get many results
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search("pl");
        assertTrue(results.size() <= 10, "Should return at most 10 results");
    }

    @Test
    void testSearch_noMatch_shouldReturnEmpty() {
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search("xyznonexistent99");
        assertTrue(results.isEmpty());
    }

    @Test
    void testPlantDataConstructors() {
        PlantDatabaseService.PlantData plant1 = new PlantDatabaseService.PlantData();
        assertNull(plant1.nomFrancais);

        PlantDatabaseService.PlantData plant2 = new PlantDatabaseService.PlantData(
                "Test Plant", "Testus plantus", 7, "Lumière vive");
        assertEquals("Test Plant", plant2.nomFrancais);
        assertEquals("Testus plantus", plant2.nomLatin);
        assertEquals(7, plant2.arrosageFrequenceJours);
        assertEquals("Lumière vive", plant2.luminosite);
    }

    @Test
    void testSearch_byLatinName_shouldWork() {
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search("deliciosa");
        assertFalse(results.isEmpty(), "Should find plants by Latin name fragment");
    }

    @Test
    void testGetByName_caseInsensitive() {
        PlantDatabaseService.PlantData plant = plantDatabaseService.getByName("monstera deliciosa");
        assertNotNull(plant, "getByName should be case insensitive");
    }

    @Test
    void testSearch_trimmedQuery() {
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search("  Monstera  ");
        assertFalse(results.isEmpty(), "Should trim whitespace from query");
    }

    @Test
    void testPlantDataFields_populated() {
        List<PlantDatabaseService.PlantData> results = plantDatabaseService.search("Monstera");
        assertFalse(results.isEmpty());
        PlantDatabaseService.PlantData plant = results.get(0);
        assertNotNull(plant.nomFrancais);
        assertNotNull(plant.nomLatin);
        assertTrue(plant.arrosageFrequenceJours > 0);
        assertNotNull(plant.luminosite);
    }
}
