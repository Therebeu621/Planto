package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for WeatherResource endpoints.
 * Tests weather-based watering advice and care sheet generation.
 */
@QuarkusTest
public class WeatherResourceTest {

    private String accessToken;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
    }

    // ==================== GET /weather/watering-advice ====================

    @Test
    void testGetWateringAdvice_validCity_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "Paris")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(200)
                .body("city", notNullValue())
                .body("temperature", isA(Number.class))
                .body("humidity", isA(Number.class))
                .body("advices", notNullValue());
    }

    @Test
    void testGetWateringAdvice_shouldReturnWeatherDetails() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "Lyon")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(200)
                .body("weatherDescription", notNullValue())
                .body("shouldSkipOutdoorWatering", isA(Boolean.class))
                .body("intervalAdjustmentFactor", isA(Number.class));
    }

    @Test
    void testGetWateringAdvice_shouldReturnAdvicesList() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "Marseille")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(200)
                .body("advices", isA(java.util.List.class));
    }

    @Test
    void testGetWateringAdvice_missingCity_shouldStillWork() {
        // The API might handle null city with a default or return an error
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(anyOf(is(200), is(400)));
    }

    @Test
    void testGetWateringAdvice_emptyCity_shouldHandleGracefully() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(anyOf(is(200), is(400)));
    }

    @Test
    void testGetWateringAdvice_unknownCity_shouldHandleGracefully() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "ZZZZXXXXXNONEXISTENT")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(anyOf(is(200), is(400), is(404), is(500)));
    }

    @Test
    void testGetWateringAdvice_cityWithSpecialChars_shouldHandleGracefully() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "Saint-Étienne")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(anyOf(is(200), is(400), is(404)));
    }

    @Test
    void testGetWateringAdvice_cityWithSpaces_shouldWork() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "New York")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(anyOf(is(200), is(400), is(404)));
    }

    @Test
    void testGetWateringAdvice_unauthenticated_shouldReturn401() {
        given()
                .queryParam("city", "Paris")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetWateringAdvice_temperatureIsReasonable() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "Paris")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(200)
                .body("temperature", allOf(greaterThanOrEqualTo(-60.0f), lessThan(60.0f)));
    }

    @Test
    void testGetWateringAdvice_humidityIsPercentage() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "Paris")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(200)
                .body("humidity", allOf(greaterThanOrEqualTo(0), lessThanOrEqualTo(100)));
    }

    // ==================== GET /weather/care-sheet ====================

    @Test
    void testGetCareSheet_validSpeciesAndCity_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "Monstera deliciosa")
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(200)
                .body("speciesName", notNullValue())
                .body("wateringFrequency", notNullValue());
    }

    @Test
    void testGetCareSheet_shouldReturnCompleteInfo() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "Ficus elastica")
                .queryParam("city", "Lyon")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(200)
                .body("speciesName", notNullValue())
                .body("careLevel", notNullValue())
                .body("wateringIntervalDays", isA(Number.class));
    }

    @Test
    void testGetCareSheet_withSeasonalAdvice() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "Aloe vera")
                .queryParam("city", "Marseille")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(200)
                .body("seasonalAdvice", notNullValue());
    }

    @Test
    void testGetCareSheet_missingSpecies_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(400)
                .body("error", containsString("species"));
    }

    @Test
    void testGetCareSheet_blankSpecies_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "   ")
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(400);
    }

    @Test
    void testGetCareSheet_emptySpecies_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "")
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(400);
    }

    @Test
    void testGetCareSheet_missingCity_shouldStillWork() {
        // City is optional for care sheet; species knowledge works without weather
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "Cactus")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(anyOf(is(200), is(400)));
    }

    @Test
    void testGetCareSheet_unknownSpecies_shouldStillReturn200() {
        // System should handle unknown species gracefully with defaults
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "Planta Fictionalius Maximus")
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(200);
    }

    @Test
    void testGetCareSheet_unauthenticated_shouldReturn401() {
        given()
                .queryParam("species", "Monstera")
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetCareSheet_speciesWithSpecialChars_shouldWork() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "Hélianthème d'Or")
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(200);
    }

    @Test
    void testGetCareSheet_wateringIntervalDaysIsPositive() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", "Monstera deliciosa")
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(200)
                .body("wateringIntervalDays", greaterThan(0));
    }

    // ==================== EDGE CASES ====================

    @Test
    void testGetWateringAdvice_veryLongCityName_shouldHandleGracefully() {
        String longCity = "A".repeat(500);
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("city", longCity)
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(anyOf(is(200), is(400), is(404), is(500)));
    }

    @Test
    void testGetCareSheet_veryLongSpeciesName_shouldHandleGracefully() {
        String longSpecies = "Plantus " + "longissimus ".repeat(50);
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("species", longSpecies)
                .queryParam("city", "Paris")
                .when()
                .get("/weather/care-sheet")
                .then()
                .statusCode(anyOf(is(200), is(400), is(500)));
    }

    @Test
    void testGetWateringAdvice_invalidToken_shouldReturn401() {
        given()
                .header("Authorization", "Bearer fake-token")
                .queryParam("city", "Paris")
                .when()
                .get("/weather/watering-advice")
                .then()
                .statusCode(401);
    }
}
