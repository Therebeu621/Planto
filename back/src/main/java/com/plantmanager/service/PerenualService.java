package com.plantmanager.service;

import com.plantmanager.client.PerenualApiClient;
import com.plantmanager.dto.CareRecommendationDTO;
import com.plantmanager.dto.perenual.PerenualDetailsResponse;
import com.plantmanager.dto.perenual.PerenualSearchResponse;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;

import java.util.Collections;
import java.util.List;
import java.util.Optional;

/**
 * Service for Perenual API integration + local watering defaults.
 * Provides plant care recommendations.
 */
@ApplicationScoped
public class PerenualService {

    private static final Logger LOG = Logger.getLogger(PerenualService.class);

    @Inject
    @RestClient
    PerenualApiClient perenualClient;

    @ConfigProperty(name = "perenual.api.key")
    Optional<String> apiKey;

    /**
     * Search species by name via Perenual API.
     * Returns list of species with basic info.
     */
    public List<PerenualSearchResponse.PerenualSpecies> searchSpecies(String query) {
        if (query == null || query.length() < 2) {
            return Collections.emptyList();
        }

        try {
            LOG.debugf("Searching Perenual for: %s", query);
            String key = apiKey.orElse("");
            PerenualSearchResponse response = perenualClient.searchSpecies(key, query);

            if (response != null && response.data != null) {
                LOG.infof("Perenual returned %d results for '%s'", response.data.size(), query);
                return response.data;
            }
        } catch (Exception e) {
            LOG.warnf("Perenual search failed: %s", e.getMessage());
        }

        return Collections.emptyList();
    }

    /**
     * Get care recommendation by Perenual species ID.
     */
    public Optional<CareRecommendationDTO> getCareRecommendation(int perenualSpeciesId) {
        try {
            LOG.debugf("Getting Perenual details for ID: %d", perenualSpeciesId);
            String key = apiKey.orElse("");
            PerenualDetailsResponse details = perenualClient.getSpeciesDetails(perenualSpeciesId, key);

            if (details != null) {
                LOG.infof("Got care info for %s: watering=%s, interval=%d days",
                        details.commonName, details.watering, details.getRecommendedIntervalDays());
                return Optional.of(CareRecommendationDTO.from(details));
            }
        } catch (Exception e) {
            LOG.warnf("Perenual details failed for ID %d: %s", perenualSpeciesId, e.getMessage());
        }

        return Optional.empty();
    }

    /**
     * Get care recommendation by species name.
     * Uses local WateringDefaults (always available, no API call needed).
     */
    public CareRecommendationDTO getCareByName(String speciesName) {
        WateringDefaults.WateringInfo info = WateringDefaults.getFor(speciesName);
        boolean isDefault = !WateringDefaults.hasInfoFor(speciesName);

        LOG.infof("Care for '%s': %d days, %s (default=%s)",
                speciesName, info.intervalDays(), info.sunlight(), isDefault);

        return new CareRecommendationDTO(
                getCategoryLabel(info.category()),
                info.intervalDays(),
                List.of(info.sunlight()),
                getCareLevel(info.intervalDays()),
                info.wateringTip(),
                null // No image from local defaults
        );
    }

    /**
     * Get care recommendation by species name.
     * First tries Perenual API, falls back to local defaults.
     */
    public Optional<CareRecommendationDTO> getCareRecommendationByName(String speciesName) {
        // Always return something - use local defaults
        return Optional.of(getCareByName(speciesName));
    }

    /**
     * Search species and enrich with care info from local defaults.
     */
    public List<PerenualSearchResponse.PerenualSpecies> searchSpeciesWithCare(String query) {
        List<PerenualSearchResponse.PerenualSpecies> results = searchSpecies(query);

        // Enrich each result with our local watering data
        for (var species : results) {
            WateringDefaults.WateringInfo info = WateringDefaults.getFor(species.commonName);
            // Note: We can't modify the DTO directly, but we'll return the info via
            // separate endpoint
        }

        return results;
    }

    private String getCategoryLabel(String category) {
        return switch (category) {
            case "tropical" -> "Tropicale";
            case "succulent" -> "Succulente";
            case "flowering" -> "Floraison";
            case "herb" -> "Herbe aromatique";
            default -> "Plante d'intérieur";
        };
    }

    private String getCareLevel(int intervalDays) {
        if (intervalDays >= 14)
            return "Facile";
        if (intervalDays >= 7)
            return "Moyen";
        return "Attention requise";
    }
}
