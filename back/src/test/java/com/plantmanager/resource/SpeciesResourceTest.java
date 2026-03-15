package com.plantmanager.resource;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@QuarkusTest
public class SpeciesResourceTest {

    @Test
    void testGetDatabaseStatus_shouldReturnReady() {
        given()
                .when()
                .get("/species/status")
                .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .body("status", equalTo("ready"))
                .body("plantCount", greaterThan(0))
                .body("source", equalTo("local-json"));
    }

    @Test
    void testSearchPlants_shouldReturnResults() {
        given()
                .queryParam("q", "Monstera")
                .when()
                .get("/species/search")
                .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .body("size()", greaterThan(0))
                .body("nomFrancais", hasItem(containsString("Monstera")))
                .body("nomLatin", hasItem(containsString("Monstera")));
    }

    @Test
    void testSearchPlants_shortQuery_shouldReturn400() {
        given()
                .queryParam("q", "a")
                .when()
                .get("/species/search")
                .then()
                .statusCode(400);
    }

    @Test
    void testSearchPlants_missingQuery_shouldReturn400() {
        given()
                .when()
                .get("/species/search")
                .then()
                .statusCode(400);
    }

    @Test
    void testGetPlantByName_exactMatch_shouldReturnDetails() {
        // Assuming "Monstera deliciosa" exists in the DB (standard test data)
        given()
                .queryParam("name", "Monstera deliciosa")
                .when()
                .get("/species/by-name")
                .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .body("nomFrancais", equalTo("Monstera deliciosa")) // Or verifying it exists
                .body("nomLatin", notNullValue())
                .body("luminosite", notNullValue());
    }

    @Test
    void testGetPlantByName_notFound_shouldReturn404() {
        given()
                .queryParam("name", "PlanteInexistante12345")
                .when()
                .get("/species/by-name")
                .then()
                .statusCode(404);
    }

    @Test
    void testGetPlantByName_missingName_shouldReturn400() {
        given()
                .when()
                .get("/species/by-name")
                .then()
                .statusCode(400);
    }
}
