package com.plantmanager.health;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@QuarkusTest
public class DatabaseHealthCheckTest {

    @Test
    void testLivenessEndpoint_shouldIncludeDatabaseCheck() {
        given()
                .basePath("/")
                .when()
                .get("/q/health/live")
                .then()
                .statusCode(200)
                .body("status", equalTo("UP"))
                .body("checks.name", hasItem("database"));
    }

    @Test
    void testDatabaseCheckInHealth_shouldBeUp() {
        given()
                .basePath("/")
                .when()
                .get("/q/health")
                .then()
                .statusCode(200)
                .body("status", equalTo("UP"));
    }
}
