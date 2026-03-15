package com.plantmanager.resource;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.is;

@QuarkusTest
public class HealthCheckTest {

    /**
     * GET /q/health — overall health should return 200 with status UP.
     */
    @Test
    void testOverallHealth_shouldReturnUp() {
        given()
                .basePath("/")
                .when()
                .get("/q/health")
                .then()
                .statusCode(200)
                .body("status", is("UP"));
    }

    /**
     * GET /q/health/live — liveness should return 200 and include the "application" check.
     */
    @Test
    void testLiveness_shouldIncludeApplicationCheck() {
        given()
                .basePath("/")
                .when()
                .get("/q/health/live")
                .then()
                .statusCode(200)
                .body("status", is("UP"))
                .body("checks.name", hasItem("application"));
    }

    /**
     * GET /q/health/live — liveness should include the "database" check.
     */
    @Test
    void testLiveness_shouldIncludeDatabaseCheck() {
        given()
                .basePath("/")
                .when()
                .get("/q/health/live")
                .then()
                .statusCode(200)
                .body("status", is("UP"))
                .body("checks.name", hasItem("database"));
    }

    /**
     * GET /q/health/live — application check should have data name = "plant-backend".
     */
    @Test
    void testLiveness_applicationCheckData() {
        given()
                .basePath("/")
                .when()
                .get("/q/health/live")
                .then()
                .statusCode(200)
                .body("checks.find { it.name == 'application' }.data.name",
                        equalTo("plant-backend"));
    }

    /**
     * GET /q/health/ready — readiness should return 200 and include "trefle-api" check.
     */
    @Test
    void testReadiness_shouldIncludeTrefleApiCheck() {
        given()
                .basePath("/")
                .when()
                .get("/q/health/ready")
                .then()
                .statusCode(200)
                .body("status", is("UP"))
                .body("checks.name", hasItem("trefle-api"));
    }

    /**
     * GET /q/health/ready — trefle-api check should be UP (possibly degraded, but still UP).
     */
    @Test
    void testReadiness_trefleApiCheckShouldBeUp() {
        given()
                .basePath("/")
                .when()
                .get("/q/health/ready")
                .then()
                .statusCode(200)
                .body("checks.find { it.name == 'trefle-api' }.status",
                        equalTo("UP"));
    }
}
