package com.plantmanager.health;

import io.quarkus.test.junit.QuarkusTest;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

@QuarkusTest
public class ApplicationHealthCheckTest {

    @Test
    void testCall_shouldReturnUp() {
        ApplicationHealthCheck healthCheck = new ApplicationHealthCheck();
        HealthCheckResponse response = healthCheck.call();

        assertNotNull(response);
        assertEquals("application", response.getName());
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertTrue(response.getData().isPresent());
        assertEquals("plant-backend", response.getData().get().get("name"));
        assertEquals("1.0.0", response.getData().get().get("version"));
    }

    @Test
    void testLivenessEndpoint_shouldBeUp() {
        given()
                .basePath("/")
                .when()
                .get("/q/health/live")
                .then()
                .statusCode(200)
                .body("status", equalTo("UP"))
                .body("checks.name", hasItem("application"));
    }
}
