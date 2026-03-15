package com.plantmanager.client;

import com.plantmanager.dto.weather.OpenWeatherResponse;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.QueryParam;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * REST client for OpenWeatherMap API.
 * Provides current weather and forecast data for intelligent watering scheduling.
 * API docs: https://openweathermap.org/api
 */
@RegisterRestClient(configKey = "openweather-api")
@Path("/data/2.5")
public interface OpenWeatherClient {

    /**
     * Get current weather for a city.
     * Example: GET /data/2.5/weather?q=Paris&appid=xxx&units=metric&lang=fr
     */
    @GET
    @Path("/weather")
    OpenWeatherResponse getCurrentWeather(
            @QueryParam("q") String city,
            @QueryParam("appid") String apiKey,
            @QueryParam("units") String units,
            @QueryParam("lang") String lang);

    /**
     * Get current weather by coordinates.
     */
    @GET
    @Path("/weather")
    OpenWeatherResponse getCurrentWeatherByCoords(
            @QueryParam("lat") double lat,
            @QueryParam("lon") double lon,
            @QueryParam("appid") String apiKey,
            @QueryParam("units") String units,
            @QueryParam("lang") String lang);
}
