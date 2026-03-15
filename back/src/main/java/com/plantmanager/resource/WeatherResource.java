package com.plantmanager.resource;

import com.plantmanager.dto.weather.PlantCareSheetDTO;
import com.plantmanager.dto.weather.WeatherWateringAdviceDTO;
import com.plantmanager.service.WeatherService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/**
 * REST Resource for weather-based watering intelligence.
 * Provides weather data, watering advice, and enriched care sheets.
 */
@Path("/weather")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
@Tag(name = "Weather", description = "Intelligence météo pour l'arrosage")
public class WeatherResource {

    @Inject
    WeatherService weatherService;

    /**
     * Get weather-based watering advice for a city.
     * Analyzes current weather conditions and provides intelligent recommendations.
     */
    @GET
    @Path("/watering-advice")
    @Operation(summary = "Conseils d'arrosage selon la météo",
            description = "Analyse les conditions météo et recommande des ajustements d'arrosage")
    public Response getWateringAdvice(@QueryParam("city") String city) {
        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice(city);
        return Response.ok(advice).build();
    }

    /**
     * Generate an enriched care sheet for a plant species.
     * Combines species knowledge with weather data for comprehensive advice.
     */
    @GET
    @Path("/care-sheet")
    @Operation(summary = "Fiche de soin enrichie",
            description = "Génère une fiche de soin complète avec conseils saisonniers et météo")
    public Response getCareSheet(
            @QueryParam("species") String species,
            @QueryParam("city") String city) {
        if (species == null || species.isBlank()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\":\"Parameter 'species' is required\"}")
                    .build();
        }
        PlantCareSheetDTO sheet = weatherService.generateCareSheet(species, city);
        return Response.ok(sheet).build();
    }
}
