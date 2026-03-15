package com.plantmanager.client;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.QueryParam;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

import com.plantmanager.dto.trefle.TrefleSearchResponse;
import com.plantmanager.dto.trefle.TrefleDetailResponse;

/**
 * REST client for Trefle.io Plant API.
 * Auto-configured via application.properties (key: trefle-api)
 */
@RegisterRestClient(configKey = "trefle-api")
@Path("/")
public interface TrefleApiClient {

        /**
         * Search plants by name.
         * Example: GET /plants/search?q=rose&token=xxx
         */
        @GET
        @Path("/plants/search")
        TrefleSearchResponse searchPlants(
                        @QueryParam("token") String token,
                        @QueryParam("q") String query);

        /**
         * Get plant details by Trefle ID.
         * Example: GET /plants/123?token=xxx
         */
        @GET
        @Path("/plants/{id}")
        TrefleDetailResponse getPlantById(
                        @PathParam("id") int trefleId,
                        @QueryParam("token") String token);
}
