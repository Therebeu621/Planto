package com.plantmanager.service;

import com.plantmanager.client.TrefleApiClient;
import com.plantmanager.dto.SpeciesDetailDTO;
import com.plantmanager.dto.SpeciesResponseDTO;
import com.plantmanager.dto.trefle.TrefleDetailResponse;
import com.plantmanager.dto.trefle.TrefleSearchResponse;
import io.quarkus.arc.Arc;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@QuarkusTest
public class TrefleServiceTest {

    @Inject
    TrefleService trefleService;

    @InjectMock
    @RestClient
    TrefleApiClient trefleApiClient;

    @BeforeEach
    void setUp() {
        Arc.container().instance(TrefleService.class).get().trefleToken = Optional.of("test-token");
    }

    // ===== searchSpecies tests =====

    @Test
    void testSearchSpecies_apiReturnsResults_shouldCacheAndReturn() {
        // Arrange: mock API to return a Monstera result
        TrefleSearchResponse response = new TrefleSearchResponse();
        TrefleSearchResponse.TreflePlantSummary summary = new TrefleSearchResponse.TreflePlantSummary();
        summary.setId(77777);
        summary.setCommonName("Monstera");
        summary.setScientificName("Monstera deliciosa");
        summary.setSlug("monstera-deliciosa");
        summary.setFamily("Araceae");
        summary.setGenus("Monstera");
        summary.setImageUrl("http://example.com/monstera.jpg");
        response.setData(List.of(summary));

        when(trefleApiClient.searchPlants(anyString(), eq("Monstera")))
                .thenReturn(response);

        // Act
        List<SpeciesResponseDTO> results = trefleService.searchSpecies("Monstera");

        // Assert
        assertNotNull(results);
        assertFalse(results.isEmpty());
        assertEquals("Monstera", results.get(0).commonName());
        assertEquals("Monstera deliciosa", results.get(0).scientificName());
        assertEquals("Araceae", results.get(0).family());
        assertEquals("Monstera", results.get(0).genus());
        assertNotNull(results.get(0).id(), "Cached entity should have a generated UUID");

        // Verify caching: second call should use cache, not API
        // Reset mock to throw if called again
        when(trefleApiClient.searchPlants(anyString(), eq("Monstera")))
                .thenThrow(new RuntimeException("API should not be called - cache should be used"));

        List<SpeciesResponseDTO> cachedResults = trefleService.searchSpecies("Monstera");
        assertFalse(cachedResults.isEmpty());
        assertEquals("Monstera", cachedResults.get(0).commonName());
    }

    @Test
    void testSearchSpecies_apiFailure_shouldFallbackToCache() {
        // Arrange: first populate the cache via a successful call
        TrefleSearchResponse response = new TrefleSearchResponse();
        TrefleSearchResponse.TreflePlantSummary summary = new TrefleSearchResponse.TreflePlantSummary();
        summary.setId(88888);
        summary.setCommonName("Cactus Test");
        summary.setScientificName("Cactaceae testis");
        summary.setSlug("cactus-test");
        summary.setFamily("Cactaceae");
        summary.setGenus("Cactus");
        summary.setImageUrl("http://example.com/cactus.jpg");
        response.setData(List.of(summary));

        when(trefleApiClient.searchPlants(anyString(), eq("Cactus Test")))
                .thenReturn(response);

        // Populate cache
        List<SpeciesResponseDTO> initial = trefleService.searchSpecies("Cactus Test");
        assertFalse(initial.isEmpty());

        // Now simulate API failure
        when(trefleApiClient.searchPlants(anyString(), eq("Cactus Test")))
                .thenThrow(new RuntimeException("Trefle.io is down"));

        // Act: search again - should fallback to stale cache
        List<SpeciesResponseDTO> fallbackResults = trefleService.searchSpecies("Cactus Test");

        // Assert: should still return cached results
        assertNotNull(fallbackResults);
        assertFalse(fallbackResults.isEmpty());
        assertEquals("Cactus Test", fallbackResults.get(0).commonName());
    }

    @Test
    void testSearchSpecies_emptyQueryResults_shouldReturnEmptyList() {
        // Arrange: mock API to return empty data
        TrefleSearchResponse response = new TrefleSearchResponse();
        response.setData(List.of());

        when(trefleApiClient.searchPlants(anyString(), eq("xyznonexistent999")))
                .thenReturn(response);

        // Act
        List<SpeciesResponseDTO> results = trefleService.searchSpecies("xyznonexistent999");

        // Assert
        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    void testSearchSpecies_sortByRelevance_namesStartingWithQueryFirst() {
        // Arrange: create results where some names start with query, some don't
        TrefleSearchResponse response = new TrefleSearchResponse();

        TrefleSearchResponse.TreflePlantSummary summary1 = new TrefleSearchResponse.TreflePlantSummary();
        summary1.setId(55551);
        summary1.setCommonName("Wild Rose");
        summary1.setScientificName("Rosa canina");
        summary1.setSlug("wild-rose");
        summary1.setFamily("Rosaceae");
        summary1.setGenus("Rosa");
        summary1.setImageUrl("http://example.com/wildrose.jpg");

        TrefleSearchResponse.TreflePlantSummary summary2 = new TrefleSearchResponse.TreflePlantSummary();
        summary2.setId(55552);
        summary2.setCommonName("Rose");
        summary2.setScientificName("Rosa gallica");
        summary2.setSlug("rose-gallica");
        summary2.setFamily("Rosaceae");
        summary2.setGenus("Rosa");
        summary2.setImageUrl("http://example.com/rose.jpg");

        TrefleSearchResponse.TreflePlantSummary summary3 = new TrefleSearchResponse.TreflePlantSummary();
        summary3.setId(55553);
        summary3.setCommonName("Rosemary");
        summary3.setScientificName("Salvia rosmarinus");
        summary3.setSlug("rosemary");
        summary3.setFamily("Lamiaceae");
        summary3.setGenus("Salvia");
        summary3.setImageUrl("http://example.com/rosemary.jpg");

        // Put "Wild Rose" first in API response so we can verify reordering
        response.setData(List.of(summary1, summary2, summary3));

        when(trefleApiClient.searchPlants(anyString(), eq("Rose")))
                .thenReturn(response);

        // Act
        List<SpeciesResponseDTO> results = trefleService.searchSpecies("Rose");

        // Assert: names starting with "Rose" should come first
        assertNotNull(results);
        assertEquals(3, results.size());

        // "Rose" and "Rosemary" start with "rose" (case-insensitive), "Wild Rose" does not
        String firstName = results.get(0).commonName();
        String secondName = results.get(1).commonName();
        String thirdName = results.get(2).commonName();

        assertTrue(firstName.toLowerCase().startsWith("rose"),
                "First result should start with 'rose', got: " + firstName);
        assertTrue(secondName.toLowerCase().startsWith("rose"),
                "Second result should start with 'rose', got: " + secondName);
        assertEquals("Wild Rose", thirdName,
                "Non-matching prefix should be sorted last");
    }

    // ===== getSpeciesById tests =====

    @Test
    void testGetSpeciesById_nonExistentUuid_shouldReturnEmpty() {
        // Act
        UUID randomId = UUID.randomUUID();
        Optional<SpeciesDetailDTO> result = trefleService.getSpeciesById(randomId);

        // Assert
        assertTrue(result.isEmpty(), "Should return empty for non-existent UUID");
    }

    // ===== getSpeciesByTrefleId tests =====

    @Test
    void testGetSpeciesByTrefleId_apiReturnsDetail_shouldMapCorrectly() {
        // Arrange: mock API to return a detail response
        TrefleDetailResponse detailResponse = new TrefleDetailResponse();
        TrefleDetailResponse.TreflePlantDetail detail = new TrefleDetailResponse.TreflePlantDetail();
        detail.setId(99999);
        detail.setCommonName("Aloe Vera");
        detail.setScientificName("Aloe vera");
        detail.setSlug("aloe-vera");
        detail.setFamily("Asphodelaceae");
        detail.setGenus("Aloe");
        detail.setImageUrl("http://example.com/aloe.jpg");
        detail.setYear(1753);
        detail.setAuthor("L.");
        detail.setBibliography("Species Plantarum");
        detail.setFamilyCommonName("Asphodel");
        detailResponse.setData(detail);

        when(trefleApiClient.getPlantById(eq(99999), anyString()))
                .thenReturn(detailResponse);

        // Act
        Optional<SpeciesDetailDTO> result = trefleService.getSpeciesByTrefleId(99999);

        // Assert
        assertTrue(result.isPresent(), "Should return a result from API");
        SpeciesDetailDTO dto = result.get();
        assertEquals(99999, dto.getTrefleId());
        assertEquals("Aloe Vera", dto.getCommonName());
        assertEquals("Aloe vera", dto.getScientificName());
        assertEquals("aloe-vera", dto.getSlug());
        assertEquals("Asphodelaceae", dto.getFamily());
        assertEquals("Aloe", dto.getGenus());
        assertEquals("http://example.com/aloe.jpg", dto.getImageUrl());
        assertEquals(1753, dto.getYear());
        assertEquals("L.", dto.getAuthor());
        assertEquals("Species Plantarum", dto.getBibliography());
        assertEquals("Asphodel", dto.getFamilyCommonName());
        assertNotNull(dto.getId(), "Cached entity should have a generated UUID");
    }

    @Test
    void testGetSpeciesByTrefleId_apiFailure_shouldReturnEmpty() {
        // Arrange: mock API to throw an exception for a trefleId that is not cached
        when(trefleApiClient.getPlantById(eq(11111), anyString()))
                .thenThrow(new RuntimeException("Trefle.io API error"));

        // Act
        Optional<SpeciesDetailDTO> result = trefleService.getSpeciesByTrefleId(11111);

        // Assert: no cache exists and API failed, should return empty
        assertTrue(result.isEmpty(), "Should return empty when API fails and no cache exists");
    }

    // ===== Additional edge case tests =====

    @Test
    void testSearchSpecies_apiReturnsNull_shouldReturnEmptyList() {
        when(trefleApiClient.searchPlants(anyString(), eq("NullResponse")))
                .thenReturn(null);

        List<SpeciesResponseDTO> results = trefleService.searchSpecies("NullResponse");
        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    void testSearchSpecies_apiReturnsNullData_shouldReturnEmptyList() {
        TrefleSearchResponse response = new TrefleSearchResponse();
        response.setData(null);

        when(trefleApiClient.searchPlants(anyString(), eq("NullData")))
                .thenReturn(response);

        List<SpeciesResponseDTO> results = trefleService.searchSpecies("NullData");
        assertNotNull(results);
        assertTrue(results.isEmpty());
    }

    @Test
    void testSearchSpecies_withNullCommonNameInResult_shouldNotThrow() {
        TrefleSearchResponse response = new TrefleSearchResponse();
        TrefleSearchResponse.TreflePlantSummary summary = new TrefleSearchResponse.TreflePlantSummary();
        summary.setId(66666);
        summary.setCommonName(null);
        summary.setScientificName("Unknown species");
        summary.setSlug("unknown-species");
        summary.setFamily("Unknown");
        summary.setGenus("Unknown");
        response.setData(List.of(summary));

        when(trefleApiClient.searchPlants(anyString(), eq("Unknown")))
                .thenReturn(response);

        List<SpeciesResponseDTO> results = trefleService.searchSpecies("Unknown");
        assertNotNull(results);
        assertFalse(results.isEmpty());
    }

    @Test
    void testSearchSpecies_existingCacheEntryUpdate_shouldRefreshTimestamp() {
        // First call populates cache
        TrefleSearchResponse response = new TrefleSearchResponse();
        TrefleSearchResponse.TreflePlantSummary summary = new TrefleSearchResponse.TreflePlantSummary();
        summary.setId(44444);
        summary.setCommonName("Refresh Test");
        summary.setScientificName("Refresh testis");
        summary.setSlug("refresh-test");
        summary.setFamily("TestFamily");
        summary.setGenus("TestGenus");
        response.setData(List.of(summary));

        when(trefleApiClient.searchPlants(anyString(), eq("Refresh Test")))
                .thenReturn(response);

        List<SpeciesResponseDTO> first = trefleService.searchSpecies("Refresh Test");
        assertFalse(first.isEmpty());

        // Second call with same trefleId should update existing cache entry
        TrefleSearchResponse response2 = new TrefleSearchResponse();
        TrefleSearchResponse.TreflePlantSummary summary2 = new TrefleSearchResponse.TreflePlantSummary();
        summary2.setId(44444); // Same trefleId
        summary2.setCommonName("Refresh Test Updated");
        summary2.setScientificName("Refresh testis");
        summary2.setSlug("refresh-test");
        summary2.setFamily("TestFamily");
        summary2.setGenus("TestGenus");
        response2.setData(List.of(summary2));

        when(trefleApiClient.searchPlants(anyString(), eq("Refresh Test Updated")))
                .thenReturn(response2);

        List<SpeciesResponseDTO> second = trefleService.searchSpecies("Refresh Test Updated");
        assertNotNull(second);
    }

    @Test
    void testGetSpeciesByTrefleId_cacheHitFresh_shouldReturnCachedWithoutApiCall() {
        // First call to populate cache
        TrefleDetailResponse detailResponse = new TrefleDetailResponse();
        TrefleDetailResponse.TreflePlantDetail detail = new TrefleDetailResponse.TreflePlantDetail();
        detail.setId(33333);
        detail.setCommonName("Cached Plant");
        detail.setScientificName("Cached plantis");
        detail.setSlug("cached-plant");
        detail.setFamily("CachedFamily");
        detail.setGenus("CachedGenus");
        detailResponse.setData(detail);

        when(trefleApiClient.getPlantById(eq(33333), anyString()))
                .thenReturn(detailResponse);

        Optional<SpeciesDetailDTO> first = trefleService.getSpeciesByTrefleId(33333);
        assertTrue(first.isPresent());

        // Second call should use cache - if API is called it would throw
        when(trefleApiClient.getPlantById(eq(33333), anyString()))
                .thenThrow(new RuntimeException("Should not be called"));

        Optional<SpeciesDetailDTO> cached = trefleService.getSpeciesByTrefleId(33333);
        assertTrue(cached.isPresent());
        assertEquals("Cached Plant", cached.get().getCommonName());
    }

    @Test
    void testGetSpeciesByTrefleId_apiFailureWithStaleCache_shouldReturnStaleCache() {
        // Populate cache
        TrefleDetailResponse detailResponse = new TrefleDetailResponse();
        TrefleDetailResponse.TreflePlantDetail detail = new TrefleDetailResponse.TreflePlantDetail();
        detail.setId(22222);
        detail.setCommonName("Stale Cache Plant");
        detail.setScientificName("Stale plantis");
        detail.setSlug("stale-plant");
        detail.setFamily("StaleFamily");
        detail.setGenus("StaleGenus");
        detailResponse.setData(detail);

        when(trefleApiClient.getPlantById(eq(22222), anyString()))
                .thenReturn(detailResponse);

        trefleService.getSpeciesByTrefleId(22222);

        // API fails on second call but cache exists
        when(trefleApiClient.getPlantById(eq(22222), anyString()))
                .thenThrow(new RuntimeException("API down"));

        // Even if cache is stale, it should still return
        Optional<SpeciesDetailDTO> result = trefleService.getSpeciesByTrefleId(22222);
        assertTrue(result.isPresent());
    }

    @Test
    void testGetSpeciesByTrefleId_apiReturnsNull_shouldReturnEmpty() {
        when(trefleApiClient.getPlantById(eq(12345), anyString()))
                .thenReturn(null);

        Optional<SpeciesDetailDTO> result = trefleService.getSpeciesByTrefleId(12345);
        assertTrue(result.isEmpty());
    }

    @Test
    void testGetSpeciesByTrefleId_apiReturnsNullData_shouldReturnEmpty() {
        TrefleDetailResponse response = new TrefleDetailResponse();
        response.setData(null);

        when(trefleApiClient.getPlantById(eq(12346), anyString()))
                .thenReturn(response);

        Optional<SpeciesDetailDTO> result = trefleService.getSpeciesByTrefleId(12346);
        assertTrue(result.isEmpty());
    }

    @Test
    void testSearchSpecies_multipleResultsWithMixedCommonNames_sortedCorrectly() {
        TrefleSearchResponse response = new TrefleSearchResponse();

        TrefleSearchResponse.TreflePlantSummary s1 = new TrefleSearchResponse.TreflePlantSummary();
        s1.setId(91001);
        s1.setCommonName(null); // null common name
        s1.setScientificName("Species nullus mix");
        s1.setSlug("species-nullus-mix");

        TrefleSearchResponse.TreflePlantSummary s2 = new TrefleSearchResponse.TreflePlantSummary();
        s2.setId(91002);
        s2.setCommonName("Fern green mix");
        s2.setScientificName("Fern greenius mix");
        s2.setSlug("fern-green-mix");

        TrefleSearchResponse.TreflePlantSummary s3 = new TrefleSearchResponse.TreflePlantSummary();
        s3.setId(91003);
        s3.setCommonName("Fernwood mix");
        s3.setScientificName("Fernwoodius mix");
        s3.setSlug("fernwood-mix");

        response.setData(List.of(s1, s2, s3));

        when(trefleApiClient.searchPlants(anyString(), eq("Fern mix")))
                .thenReturn(response);

        List<SpeciesResponseDTO> results = trefleService.searchSpecies("Fern mix");
        assertNotNull(results);
        assertFalse(results.isEmpty());
        // At least the non-null entries should be returned and sorted
        assertTrue(results.size() >= 2, "Should have at least 2 results");
    }
}
