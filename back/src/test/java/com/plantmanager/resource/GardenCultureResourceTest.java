package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for GardenCultureResource endpoints.
 * Tests garden culture CRUD (semis, croissance, recolte) and status transitions.
 */
@QuarkusTest
public class GardenCultureResourceTest {

    private String accessToken;
    private String houseId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");
    }

    // ==================== POST /garden/house/{houseId} ====================

    @Test
    void testCreateCulture_validData_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "Tomate",
                            "variety": "Coeur de Boeuf",
                            "sowDate": "%s",
                            "expectedHarvestDate": "%s",
                            "notes": "Premier semis de la saison",
                            "rowNumber": 1,
                            "columnNumber": 3
                        }
                        """.formatted(LocalDate.now().toString(), LocalDate.now().plusDays(90).toString()))
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(201)
                .body("id", notNullValue())
                .body("plantName", equalTo("Tomate"))
                .body("variety", equalTo("Coeur de Boeuf"))
                .body("status", equalTo("SEMIS"));
    }

    @Test
    void testCreateCulture_minimalData_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "Basilic"
                        }
                        """)
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(201)
                .body("plantName", equalTo("Basilic"));
    }

    @Test
    void testCreateCulture_missingPlantName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "variety": "Cherry"
                        }
                        """)
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateCulture_blankPlantName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "   "
                        }
                        """)
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateCulture_nameTooLong_shouldReturn400() {
        String longName = "A".repeat(101);
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "%s"
                        }
                        """.formatted(longName))
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateCulture_nonExistentHouse_shouldReturn403or404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "Carotte"
                        }
                        """)
                .when()
                .post("/garden/house/" + UUID.randomUUID())
                .then()
                .statusCode(anyOf(is(403), is(404)));
    }

    @Test
    void testCreateCulture_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "Carotte"
                        }
                        """)
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(401);
    }

    @Test
    void testCreateCulture_withGridPosition_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "Radis",
                            "rowNumber": 5,
                            "columnNumber": 10
                        }
                        """)
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(201)
                .body("rowNumber", is(5))
                .body("columnNumber", is(10));
    }

    // ==================== GET /garden/house/{houseId} ====================

    @Test
    void testGetCultures_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/garden/house/" + houseId)
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetCultures_withStatusFilter_shouldReturn200() {
        // Create a culture first
        createCulture("Filtre Test " + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("status", "SEMIS")
                .when()
                .get("/garden/house/" + houseId)
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetCultures_nonExistentHouse_shouldReturn403or404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/garden/house/" + UUID.randomUUID())
                .then()
                .statusCode(anyOf(is(403), is(404)));
    }

    @Test
    void testGetCultures_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/garden/house/" + houseId)
                .then()
                .statusCode(401);
    }

    // ==================== GET /garden/{cultureId} ====================

    @Test
    void testGetCulture_existing_shouldReturn200() {
        String cultureId = createCulture("Detail Test " + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/garden/" + cultureId)
                .then()
                .statusCode(200)
                .body("id", equalTo(cultureId))
                .body("plantName", notNullValue())
                .body("status", notNullValue());
    }

    @Test
    void testGetCulture_nonExistent_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/garden/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testGetCulture_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/garden/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    // ==================== PUT /garden/{cultureId}/status ====================

    @Test
    void testUpdateStatus_semisToGermination_shouldReturn200() {
        String cultureId = createCulture("Status Transition " + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "GERMINATION",
                            "notes": "Premiere pousse visible"
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(200)
                .body("status", equalTo("GERMINATION"));
    }

    @Test
    void testUpdateStatus_withGrowthData_shouldReturn200() {
        String cultureId = createCulture("Growth Data " + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "CROISSANCE",
                            "heightCm": 15.5,
                            "notes": "Belle croissance"
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(200);
    }

    @Test
    void testUpdateStatus_toRecolte_shouldReturn200() {
        String cultureId = createCulture("Recolte " + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "RECOLTE",
                            "harvestQuantity": "2.5 kg",
                            "notes": "Bonne recolte"
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(200);
    }

    @Test
    void testUpdateStatus_missingNewStatus_shouldReturn400() {
        String cultureId = createCulture("Bad Status " + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "notes": "No status provided"
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(400);
    }

    @Test
    void testUpdateStatus_invalidStatus_shouldReturn400() {
        String cultureId = createCulture("Invalid Status " + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "INVALID_STATUS"
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(400);
    }

    @Test
    void testUpdateStatus_nonExistentCulture_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "GERMINATION"
                        }
                        """)
                .when()
                .put("/garden/" + UUID.randomUUID() + "/status")
                .then()
                .statusCode(404);
    }

    @Test
    void testUpdateStatus_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "GERMINATION"
                        }
                        """)
                .when()
                .put("/garden/" + UUID.randomUUID() + "/status")
                .then()
                .statusCode(401);
    }

    // ==================== DELETE /garden/{cultureId} ====================

    @Test
    void testDeleteCulture_existing_shouldReturn204() {
        String cultureId = createCulture("Delete Test " + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/garden/" + cultureId)
                .then()
                .statusCode(204);

        // Verify deleted
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/garden/" + cultureId)
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteCulture_nonExistent_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/garden/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteCulture_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/garden/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    // ==================== FULL LIFECYCLE ====================

    @Test
    void testCultureLifecycle_createToHarvest() {
        // CREATE
        String cultureId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "Lifecycle Tomate",
                            "variety": "Roma",
                            "sowDate": "%s"
                        }
                        """.formatted(LocalDate.now().toString()))
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(201)
                .body("status", equalTo("SEMIS"))
                .extract()
                .path("id");

        // GERMINATION
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "GERMINATION",
                            "heightCm": 2.0,
                            "notes": "Germination observee"
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(200)
                .body("status", equalTo("GERMINATION"));

        // CROISSANCE
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "CROISSANCE",
                            "heightCm": 30.0,
                            "notes": "En pleine croissance"
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(200)
                .body("status", equalTo("CROISSANCE"));

        // FLORAISON
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "FLORAISON",
                            "heightCm": 60.0
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(200)
                .body("status", equalTo("FLORAISON"));

        // RECOLTE
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newStatus": "RECOLTE",
                            "harvestQuantity": "3.2 kg"
                        }
                        """)
                .when()
                .put("/garden/" + cultureId + "/status")
                .then()
                .statusCode(200)
                .body("status", equalTo("RECOLTE"));

        // VERIFY DETAIL
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/garden/" + cultureId)
                .then()
                .statusCode(200)
                .body("status", equalTo("RECOLTE"))
                .body("plantName", equalTo("Lifecycle Tomate"));

        // DELETE
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/garden/" + cultureId)
                .then()
                .statusCode(204);
    }

    // ==================== HELPER ====================

    private String createCulture(String plantName) {
        return given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "plantName": "%s"
                        }
                        """.formatted(plantName))
                .when()
                .post("/garden/house/" + houseId)
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
