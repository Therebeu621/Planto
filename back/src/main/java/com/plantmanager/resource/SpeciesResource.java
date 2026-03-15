package com.plantmanager.resource;

import com.plantmanager.dto.PlantSearchResultDTO;
import com.plantmanager.service.PlantDatabaseService;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.logging.Logger;

import java.util.List;
import java.util.Map;

/**
 * REST resource for plant species operations.
 * Uses local JSON database for plant search and data.
 */
@Path("/species")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class SpeciesResource {

        private static final Logger LOG = Logger.getLogger(SpeciesResource.class);

        @Inject
        PlantDatabaseService plantDatabase;

        /**
         * Search plants by name (French or Latin).
         * GET /api/v1/species/search?q=monstera
         * 
         * Returns list of matching plants with:
         * - nomFrancais: French name
         * - nomLatin: Scientific name
         * - arrosageFrequenceJours: Watering frequency (days)
         * - luminosite: Light requirement (Plein soleil, Mi-ombre, Ombre)
         */
        @GET
        @Path("/search")
        public Response searchPlants(@QueryParam("q") String query) {
                if (query == null || query.trim().length() < 2) {
                        return Response.status(Response.Status.BAD_REQUEST)
                                        .entity("{\"error\": \"Query must be at least 2 characters\"}")
                                        .build();
                }

                LOG.infof("Plant search request: %s", query);

                List<PlantDatabaseService.PlantData> results = plantDatabase.search(query.trim());

                // Convert to DTOs
                List<PlantSearchResultDTO> dtos = results.stream()
                                .map(p -> new PlantSearchResultDTO(
                                                p.nomFrancais,
                                                p.nomLatin,
                                                p.arrosageFrequenceJours,
                                                p.luminosite))
                                .toList();

                return Response.ok(dtos).build();
        }

        /**
         * Get plant details by exact French name.
         * GET /api/v1/species/by-name?name=Monstera deliciosa
         */
        @GET
        @Path("/by-name")
        public Response getPlantByName(@QueryParam("name") String name) {
                if (name == null || name.trim().isEmpty()) {
                        return Response.status(Response.Status.BAD_REQUEST)
                                        .entity("{\"error\": \"Name is required\"}")
                                        .build();
                }

                LOG.infof("Plant lookup request: %s", name);

                PlantDatabaseService.PlantData plant = plantDatabase.getByName(name.trim());

                if (plant == null) {
                        return Response.status(Response.Status.NOT_FOUND)
                                        .entity("{\"error\": \"Plant not found: " + name + "\"}")
                                        .build();
                }

                PlantSearchResultDTO dto = new PlantSearchResultDTO(
                                plant.nomFrancais,
                                plant.nomLatin,
                                plant.arrosageFrequenceJours,
                                plant.luminosite);

                return Response.ok(dto).build();
        }

        /**
         * Get database status.
         * GET /api/v1/species/status
         */
        @GET
        @Path("/status")
        public Response getDatabaseStatus() {
                int count = plantDatabase.getPlantCount();
                return Response.ok(Map.of(
                                "source", "local-json",
                                "plantCount", count,
                                "status", count > 0 ? "ready" : "loading"))
                                .build();
        }
}
