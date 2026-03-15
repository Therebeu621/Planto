package com.plantmanager.client;

import com.plantmanager.dto.perenual.PerenualSearchResponse;
import com.plantmanager.dto.perenual.PerenualDetailsResponse;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.QueryParam;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * REST client for Perenual Plant API.
 * Provides care recommendations (watering, sunlight, etc.)
 * API docs: https://perenual.com/docs/api
 */
@RegisterRestClient(configKey = "perenual-api")
@Path("/")
public interface PerenualApiClient {

    /**
     * Search plant species by name.
     * Example: GET /species-list?key=xxx&q=monstera
     */
    @GET
    @Path("/species-list")
    PerenualSearchResponse searchSpecies(
            @QueryParam("key") String apiKey,
            @QueryParam("q") String query);

    /**
     * Get detailed species info including care data.
     * Example: GET /species/details/1?key=xxx
     */
    @GET
    @Path("/species/details/{id}")
    PerenualDetailsResponse getSpeciesDetails(
            @PathParam("id") int speciesId,
            @QueryParam("key") String apiKey);
}
