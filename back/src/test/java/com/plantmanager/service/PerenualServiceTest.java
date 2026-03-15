package com.plantmanager.service;

import com.plantmanager.client.PerenualApiClient;
import com.plantmanager.dto.CareRecommendationDTO;
import com.plantmanager.dto.perenual.PerenualDetailsResponse;
import com.plantmanager.dto.perenual.PerenualSearchResponse;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@QuarkusTest
public class PerenualServiceTest {

    @Inject
    PerenualService perenualService;

    @InjectMock
    @RestClient
    PerenualApiClient perenualApiClient;

    // ===== searchSpecies tests =====

    @Test
    void testSearchSpecies_apiReturnsResults_shouldReturnList() {
        // Arrange
        PerenualSearchResponse response = new PerenualSearchResponse();
        PerenualSearchResponse.PerenualSpecies species = new PerenualSearchResponse.PerenualSpecies();
        species.id = 1;
        species.commonName = "Monstera";
        species.scientificName = List.of("Monstera deliciosa");
        species.cycle = "Perennial";
        species.watering = "Average";
        species.sunlight = List.of("part shade");
        response.data = List.of(species);

        when(perenualApiClient.searchSpecies(anyString(), eq("Monstera")))
                .thenReturn(response);

        // Act
        List<PerenualSearchResponse.PerenualSpecies> results = perenualService.searchSpecies("Monstera");

        // Assert
        assertNotNull(results);
        assertEquals(1, results.size());
        assertEquals("Monstera", results.get(0).commonName);
        assertEquals("Average", results.get(0).watering);
    }

    @Test
    void testSearchSpecies_apiReturnsNull_shouldReturnEmptyList() {
        when(perenualApiClient.searchSpecies(anyString(), eq("NullPlant")))
                .thenReturn(null);

        List<PerenualSearchResponse.PerenualSpecies> results = perenualService.searchSpecies("NullPlant");

        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    void testSearchSpecies_apiThrows_shouldReturnEmptyList() {
        when(perenualApiClient.searchSpecies(anyString(), eq("ErrorPlant")))
                .thenThrow(new RuntimeException("API down"));

        List<PerenualSearchResponse.PerenualSpecies> results = perenualService.searchSpecies("ErrorPlant");

        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    void testSearchSpecies_shortQuery_shouldReturnEmptyList() {
        List<PerenualSearchResponse.PerenualSpecies> results = perenualService.searchSpecies("a");
        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    void testSearchSpecies_nullQuery_shouldReturnEmptyList() {
        List<PerenualSearchResponse.PerenualSpecies> results = perenualService.searchSpecies(null);
        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    // ===== getCareRecommendation (by ID) tests =====

    @Test
    void testGetCareRecommendation_apiReturnsDetails_shouldReturnDTO() {
        // Arrange
        PerenualDetailsResponse details = new PerenualDetailsResponse();
        details.id = 42;
        details.commonName = "Aloe Vera";
        details.scientificName = List.of("Aloe vera");
        details.watering = "Minimum";
        details.sunlight = List.of("Full sun");
        details.careLevel = "Low";
        details.description = "A succulent plant";

        PerenualDetailsResponse.WateringBenchmark benchmark = new PerenualDetailsResponse.WateringBenchmark();
        benchmark.value = "10-14";
        benchmark.unit = "days";
        details.wateringBenchmark = benchmark;

        PerenualDetailsResponse.DefaultImage image = new PerenualDetailsResponse.DefaultImage();
        image.regularUrl = "http://example.com/aloe.jpg";
        details.defaultImage = image;

        when(perenualApiClient.getSpeciesDetails(eq(42), anyString()))
                .thenReturn(details);

        // Act
        Optional<CareRecommendationDTO> result = perenualService.getCareRecommendation(42);

        // Assert
        assertTrue(result.isPresent());
        CareRecommendationDTO dto = result.get();
        assertEquals("Minimum", dto.wateringFrequency());
        assertEquals(12, dto.recommendedIntervalDays()); // (10+14)/2
        assertEquals(List.of("Full sun"), dto.sunlight());
        assertEquals("Low", dto.careLevel());
        assertEquals("http://example.com/aloe.jpg", dto.imageUrl());
    }

    @Test
    void testGetCareRecommendation_apiReturnsNull_shouldReturnEmpty() {
        when(perenualApiClient.getSpeciesDetails(eq(999), anyString()))
                .thenReturn(null);

        Optional<CareRecommendationDTO> result = perenualService.getCareRecommendation(999);

        assertTrue(result.isEmpty());
    }

    @Test
    void testGetCareRecommendation_apiThrows_shouldReturnEmpty() {
        when(perenualApiClient.getSpeciesDetails(eq(888), anyString()))
                .thenThrow(new RuntimeException("API error"));

        Optional<CareRecommendationDTO> result = perenualService.getCareRecommendation(888);

        assertTrue(result.isEmpty());
    }

    // ===== getCareByName tests =====

    @Test
    void testGetCareByName_knownSpecies_shouldReturnLocalDefaults() {
        // "monstera" is a known species in WateringDefaults
        CareRecommendationDTO result = perenualService.getCareByName("Monstera");

        assertNotNull(result);
        assertEquals(7, result.recommendedIntervalDays());
        assertEquals("Tropicale", result.wateringFrequency()); // category label for "tropical"
        assertNotNull(result.sunlight());
        assertFalse(result.sunlight().isEmpty());
        assertNull(result.imageUrl()); // no image from local defaults
    }

    @Test
    void testGetCareByName_cactus_shouldReturnSucculentDefaults() {
        CareRecommendationDTO result = perenualService.getCareByName("Cactus");

        assertNotNull(result);
        assertEquals(21, result.recommendedIntervalDays());
        assertEquals("Succulente", result.wateringFrequency()); // category label for "succulent"
        assertEquals("Facile", result.careLevel()); // intervalDays >= 14
    }

    @Test
    void testGetCareByName_basil_shouldReturnHerbDefaults() {
        CareRecommendationDTO result = perenualService.getCareByName("Basilic");

        assertNotNull(result);
        assertEquals(2, result.recommendedIntervalDays());
        assertEquals("Herbe aromatique", result.wateringFrequency()); // category label for "herb"
        assertEquals("Attention requise", result.careLevel()); // intervalDays < 7
    }

    @Test
    void testGetCareByName_unknownSpecies_shouldReturnGeneralDefaults() {
        CareRecommendationDTO result = perenualService.getCareByName("UnknownXYZPlant");

        assertNotNull(result);
        assertEquals(7, result.recommendedIntervalDays()); // default
        assertEquals("Plante d'int\u00e9rieur", result.wateringFrequency()); // default category label
        assertEquals("Moyen", result.careLevel()); // intervalDays == 7
    }

    @Test
    void testGetCareByName_orchid_shouldReturnFloweringDefaults() {
        CareRecommendationDTO result = perenualService.getCareByName("Orchid");

        assertNotNull(result);
        assertEquals(10, result.recommendedIntervalDays());
        assertEquals("Floraison", result.wateringFrequency()); // category label for "flowering"
        assertEquals("Moyen", result.careLevel()); // intervalDays >= 7 and < 14
    }

    // ===== getCareRecommendationByName tests =====

    @Test
    void testGetCareRecommendationByName_shouldAlwaysReturnPresent() {
        Optional<CareRecommendationDTO> result = perenualService.getCareRecommendationByName("AnyPlant");

        assertTrue(result.isPresent());
        assertNotNull(result.get());
    }

    // ===== searchSpeciesWithCare tests =====

    @Test
    void testSearchSpeciesWithCare_shouldReturnEnrichedResults() {
        PerenualSearchResponse response = new PerenualSearchResponse();
        PerenualSearchResponse.PerenualSpecies species = new PerenualSearchResponse.PerenualSpecies();
        species.id = 10;
        species.commonName = "Aloe";
        species.scientificName = List.of("Aloe vera");
        species.watering = "Minimum";
        species.sunlight = List.of("Full sun");
        response.data = List.of(species);

        when(perenualApiClient.searchSpecies(anyString(), eq("Aloe")))
                .thenReturn(response);

        List<PerenualSearchResponse.PerenualSpecies> results = perenualService.searchSpeciesWithCare("Aloe");

        assertNotNull(results);
        assertEquals(1, results.size());
        assertEquals("Aloe", results.get(0).commonName);
    }

    @Test
    void testSearchSpeciesWithCare_apiResponseWithNullData_shouldReturnEmpty() {
        PerenualSearchResponse response = new PerenualSearchResponse();
        response.data = null;

        when(perenualApiClient.searchSpecies(anyString(), eq("NullData")))
                .thenReturn(response);

        List<PerenualSearchResponse.PerenualSpecies> results = perenualService.searchSpeciesWithCare("NullData");

        assertNotNull(results);
        assertTrue(results.isEmpty());
    }
}
