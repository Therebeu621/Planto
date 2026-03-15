package com.plantmanager.service;

import com.plantmanager.client.TrefleApiClient;
import com.plantmanager.dto.SpeciesDetailDTO;
import com.plantmanager.dto.SpeciesResponseDTO;
import com.plantmanager.dto.trefle.TrefleDetailResponse;
import com.plantmanager.dto.trefle.TrefleSearchResponse;
import com.plantmanager.entity.SpeciesCacheEntity;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Service for Trefle.io plant species operations.
 * Implements caching to reduce API calls.
 */
@ApplicationScoped
public class TrefleService {

    private static final Logger LOG = Logger.getLogger(TrefleService.class);

    @Inject
    @RestClient
    TrefleApiClient trefleApiClient;

    @ConfigProperty(name = "trefle.api.token")
    Optional<String> trefleToken;

    @ConfigProperty(name = "trefle.cache.ttl-days", defaultValue = "7")
    int cacheTtlDays;

    /**
     * Search species by name.
     * First checks local cache, then calls Trefle.io if needed.
     */
    @Transactional
    public List<SpeciesResponseDTO> searchSpecies(String query) {
        LOG.infof("Searching species for query: %s", query);

        // 1. Check local cache first
        List<SpeciesCacheEntity> cached = SpeciesCacheEntity.searchByCommonName(query);

        // If we have cached results, check if they're fresh
        if (!cached.isEmpty() && areCacheEntriesFresh(cached)) {
            LOG.infof("Returning %d cached results for: %s", cached.size(), query);
            return sortByRelevance(mapToResponseList(cached), query);
        }

        // 2. No fresh cache - call Trefle.io API
        if (isTokenConfigured()) {
            try {
                LOG.infof("Calling Trefle.io API for: %s", query);
                TrefleSearchResponse response = trefleApiClient.searchPlants(trefleToken.orElse(""), query);

                if (response != null && response.getData() != null) {
                    List<SpeciesCacheEntity> newEntries = cacheSearchResults(response.getData());
                    LOG.infof("Cached %d new species from Trefle.io", newEntries.size());
                    return sortByRelevance(mapToResponseList(newEntries), query);
                }
            } catch (Exception e) {
                LOG.warnf("Trefle.io API error: %s. Using stale cache.", e.getMessage());
                // Fall back to stale cache
                if (!cached.isEmpty()) {
                    return sortByRelevance(mapToResponseList(cached), query);
                }
            }
        } else {
            LOG.warn("Trefle.io token not configured, using cache only");
            if (!cached.isEmpty()) {
                return sortByRelevance(mapToResponseList(cached), query);
            }
        }

        return new ArrayList<>();
    }

    /**
     * Sort results to prioritize names starting with query.
     */
    private List<SpeciesResponseDTO> sortByRelevance(List<SpeciesResponseDTO> input, String query) {
        String lowerQuery = query.toLowerCase();
        // Create mutable copy to allow sorting
        java.util.ArrayList<SpeciesResponseDTO> results = new java.util.ArrayList<>(input);
        results.sort((a, b) -> {
            String nameA = a.commonName() != null ? a.commonName().toLowerCase() : "";
            String nameB = b.commonName() != null ? b.commonName().toLowerCase() : "";
            boolean aStartsWith = nameA.startsWith(lowerQuery);
            boolean bStartsWith = nameB.startsWith(lowerQuery);

            if (aStartsWith && !bStartsWith)
                return -1;
            if (!aStartsWith && bStartsWith)
                return 1;
            return nameA.compareTo(nameB);
        });
        return results;
    }

    /**
     * Get species details by internal UUID.
     */
    public Optional<SpeciesDetailDTO> getSpeciesById(UUID id) {
        return SpeciesCacheEntity.findByIdOptional(id)
                .map(entity -> mapToDetailDTO((SpeciesCacheEntity) entity));
    }

    /**
     * Get species by Trefle ID, fetching from API if not cached.
     */
    @Transactional
    public Optional<SpeciesDetailDTO> getSpeciesByTrefleId(int trefleId) {
        // Check cache
        Optional<SpeciesCacheEntity> cached = SpeciesCacheEntity.findByTrefleId(trefleId);

        if (cached.isPresent() && SpeciesCacheEntity.isCacheValid(cached.get(), cacheTtlDays)) {
            return Optional.of(mapToDetailDTO(cached.get()));
        }

        // Fetch from API
        if (isTokenConfigured()) {
            try {
                TrefleDetailResponse response = trefleApiClient.getPlantById(trefleId, trefleToken.orElse(""));
                if (response != null && response.getData() != null) {
                    SpeciesCacheEntity entity = cacheDetailResult(response.getData());
                    return Optional.of(mapToDetailDTO(entity));
                }
            } catch (Exception e) {
                LOG.warnf("Error fetching Trefle.io details: %s", e.getMessage());
                // Return stale cache if available
                if (cached.isPresent()) {
                    return Optional.of(mapToDetailDTO(cached.get()));
                }
            }
        }

        return cached.map(this::mapToDetailDTO);
    }

    // ===== Private helper methods =====

    private boolean isTokenConfigured() {
        String token = trefleToken.orElse("");
        return !token.isBlank() && !"not-configured".equals(token);
    }

    private boolean areCacheEntriesFresh(List<SpeciesCacheEntity> entries) {
        return entries.stream()
                .allMatch(e -> SpeciesCacheEntity.isCacheValid(e, cacheTtlDays));
    }

    private List<SpeciesCacheEntity> cacheSearchResults(List<TrefleSearchResponse.TreflePlantSummary> plants) {
        List<SpeciesCacheEntity> result = new ArrayList<>();

        for (TrefleSearchResponse.TreflePlantSummary plant : plants) {
            // Check if already cached
            Optional<SpeciesCacheEntity> existing = SpeciesCacheEntity.findByTrefleId(plant.getId());

            if (existing.isPresent()) {
                // Update cache timestamp
                SpeciesCacheEntity entity = existing.get();
                entity.cachedAt = OffsetDateTime.now();
                entity.persist();
                result.add(entity);
            } else {
                // Create new cache entry
                SpeciesCacheEntity entity = new SpeciesCacheEntity();
                entity.trefleId = plant.getId();
                entity.slug = plant.getSlug();
                entity.commonName = plant.getCommonName();
                entity.scientificName = plant.getScientificName();
                entity.family = plant.getFamily();
                entity.genus = plant.getGenus();
                entity.imageUrl = plant.getImageUrl();
                entity.setYear(plant.getYear());
                entity.setAuthor(plant.getAuthor());
                entity.familyCommonName = plant.getFamilyCommonName();
                entity.cachedAt = OffsetDateTime.now();
                entity.persist();
                result.add(entity);
            }
        }

        return result;
    }

    private SpeciesCacheEntity cacheDetailResult(TrefleDetailResponse.TreflePlantDetail plant) {
        Optional<SpeciesCacheEntity> existing = SpeciesCacheEntity.findByTrefleId(plant.getId());

        SpeciesCacheEntity entity = existing.orElse(new SpeciesCacheEntity());
        entity.trefleId = plant.getId();
        entity.slug = plant.getSlug();
        entity.commonName = plant.getCommonName();
        entity.scientificName = plant.getScientificName();
        entity.family = plant.getFamily();
        entity.genus = plant.getGenus();
        entity.imageUrl = plant.getImageUrl();
        entity.setYear(plant.getYear());
        entity.setAuthor(plant.getAuthor());
        entity.bibliography = plant.getBibliography();
        entity.familyCommonName = plant.getFamilyCommonName();
        entity.cachedAt = OffsetDateTime.now();
        entity.persist();

        return entity;
    }

    private List<SpeciesResponseDTO> mapToResponseList(List<SpeciesCacheEntity> entities) {
        return entities.stream()
                .map(this::mapToResponseDTO)
                .toList();
    }

    private SpeciesResponseDTO mapToResponseDTO(SpeciesCacheEntity entity) {
        return new SpeciesResponseDTO(
                entity.id,
                entity.trefleId,
                entity.commonName,
                entity.scientificName,
                entity.family,
                entity.genus,
                entity.imageUrl);
    }

    private SpeciesDetailDTO mapToDetailDTO(SpeciesCacheEntity entity) {
        SpeciesDetailDTO dto = new SpeciesDetailDTO();
        dto.setId(entity.id);
        dto.setTrefleId(entity.trefleId);
        dto.setSlug(entity.slug);
        dto.setCommonName(entity.commonName);
        dto.setScientificName(entity.scientificName);
        dto.setFamily(entity.family);
        dto.setGenus(entity.genus);
        dto.setImageUrl(entity.imageUrl);
        dto.setYear(entity.getYear());
        dto.setAuthor(entity.getAuthor());
        dto.setBibliography(entity.bibliography);
        dto.setFamilyCommonName(entity.familyCommonName);
        return dto;
    }
}
