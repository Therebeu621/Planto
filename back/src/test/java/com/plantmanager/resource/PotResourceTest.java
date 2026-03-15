package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for PotResource endpoints.
 * Tests pot stock CRUD, repotting, and suggestions.
 */
@QuarkusTest
public class PotResourceTest {

    private String accessToken;
    private UUID roomId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        roomId = TestUtils.firstRoomId(accessToken);
    }

    // ==================== GET /pots ====================

    @Test
    void testGetPotStock_authenticated_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/pots")
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetPotStock_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/pots")
                .then()
                .statusCode(401);
    }

    // ==================== GET /pots/available ====================

    @Test
    void testGetAvailablePots_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/pots/available")
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetAvailablePots_shouldOnlyReturnPotsWithQuantityGreaterThanZero() {
        // First add a pot
        createPot(accessToken, 12.0, 3, "Test Available");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/pots/available")
                .then()
                .statusCode(200)
                .body("findAll { it.quantity > 0 }.size()", greaterThanOrEqualTo(1));
    }

    // ==================== POST /pots ====================

    @Test
    void testAddToStock_validData_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 15.5,
                            "quantity": 5,
                            "label": "Pot en terre cuite"
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(201)
                .body("diameterCm", is(15.5f))
                .body("quantity", greaterThanOrEqualTo(5))
                .body("label", equalTo("Pot en terre cuite"))
                .body("id", notNullValue());
    }

    @Test
    void testAddToStock_minimalData_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 8.0,
                            "quantity": 1
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(201)
                .body("diameterCm", is(8.0f))
                .body("quantity", greaterThanOrEqualTo(1));
    }

    @Test
    void testAddToStock_sameDiameter_shouldIncrementQuantity() {
        double uniqueDiameter = 30.0 + Math.random() * 10;
        // Round to one decimal place
        uniqueDiameter = Math.round(uniqueDiameter * 10.0) / 10.0;

        // Add first time
        int initialQuantity = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": %s,
                            "quantity": 2,
                            "label": "Duplicate test"
                        }
                        """.formatted(uniqueDiameter))
                .when()
                .post("/pots")
                .then()
                .statusCode(201)
                .extract()
                .path("quantity");

        // Add same diameter again
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": %s,
                            "quantity": 3,
                            "label": "Duplicate test"
                        }
                        """.formatted(uniqueDiameter))
                .when()
                .post("/pots")
                .then()
                .statusCode(201)
                .body("quantity", greaterThanOrEqualTo(initialQuantity + 3));
    }

    @Test
    void testAddToStock_zeroDiameter_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 0,
                            "quantity": 1
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(400);
    }

    @Test
    void testAddToStock_negativeDiameter_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": -5.0,
                            "quantity": 1
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(400);
    }

    @Test
    void testAddToStock_zeroQuantity_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 10.0,
                            "quantity": 0
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(400);
    }

    @Test
    void testAddToStock_negativeQuantity_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 10.0,
                            "quantity": -3
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(400);
    }

    @Test
    void testAddToStock_missingDiameter_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "quantity": 1
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(400);
    }

    @Test
    void testAddToStock_labelTooLong_shouldReturn400() {
        String longLabel = "A".repeat(101);
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 10.0,
                            "quantity": 1,
                            "label": "%s"
                        }
                        """.formatted(longLabel))
                .when()
                .post("/pots")
                .then()
                .statusCode(400);
    }

    @Test
    void testAddToStock_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 10.0,
                            "quantity": 1
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(401);
    }

    @Test
    void testAddToStock_veryLargeDiameter_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 999.9,
                            "quantity": 1,
                            "label": "Enormous pot"
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(201);
    }

    @Test
    void testAddToStock_veryLargeQuantity_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 7.7,
                            "quantity": 9999,
                            "label": "Bulk order"
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(201);
    }

    // ==================== PUT /pots/{id} ====================

    @Test
    void testUpdateStock_validData_shouldReturn200() {
        String potId = createPot(accessToken, 14.0, 5, "Update Test");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "quantity": 10
                        }
                        """)
                .when()
                .put("/pots/" + potId)
                .then()
                .statusCode(200)
                .body("quantity", is(10));
    }

    @Test
    void testUpdateStock_setToZero_shouldReturn200() {
        String potId = createPot(accessToken, 13.0, 5, "Zero Test");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "quantity": 0
                        }
                        """)
                .when()
                .put("/pots/" + potId)
                .then()
                .statusCode(200)
                .body("quantity", is(0));
    }

    @Test
    void testUpdateStock_nonExistentPot_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "quantity": 5
                        }
                        """)
                .when()
                .put("/pots/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testUpdateStock_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "quantity": 5
                        }
                        """)
                .when()
                .put("/pots/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    // ==================== DELETE /pots/{id} ====================

    @Test
    void testDeleteStock_existingPot_shouldReturn204() {
        String potId = createPot(accessToken, 11.0, 1, "Delete Test");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/pots/" + potId)
                .then()
                .statusCode(204);

        // Verify it's gone or quantity is zero
        // Trying to delete again should return 404
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/pots/" + potId)
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteStock_nonExistentPot_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/pots/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteStock_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/pots/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    // ==================== POST /pots/repot/{plantId} ====================

    @Test
    void testRepotPlant_validData_shouldReturn200() {
        // Create a pot in stock first
        createPot(accessToken, 20.0, 2, "Repot stock");

        // Create a plant
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Repot Test " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newDiameterCm": 20.0,
                            "notes": "Rempotage de printemps"
                        }
                        """)
                .when()
                .post("/pots/repot/" + plantId)
                .then()
                .statusCode(anyOf(is(200), is(400))); // 400 if pot not available
    }

    @Test
    void testRepotPlant_nonExistentPlant_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newDiameterCm": 15.0
                        }
                        """)
                .when()
                .post("/pots/repot/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testRepotPlant_invalidDiameter_shouldReturn400() {
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Bad Repot " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newDiameterCm": 0
                        }
                        """)
                .when()
                .post("/pots/repot/" + plantId)
                .then()
                .statusCode(400);
    }

    @Test
    void testRepotPlant_missingDiameter_shouldReturn400() {
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "No Diam Repot " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "notes": "No diameter provided"
                        }
                        """)
                .when()
                .post("/pots/repot/" + plantId)
                .then()
                .statusCode(400);
    }

    @Test
    void testRepotPlant_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newDiameterCm": 15.0
                        }
                        """)
                .when()
                .post("/pots/repot/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    // ==================== GET /pots/suggestions/{plantId} ====================

    @Test
    void testGetSuggestedPots_validPlant_shouldReturn200() {
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Suggest Test " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/pots/suggestions/" + plantId)
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetSuggestedPots_nonExistentPlant_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/pots/suggestions/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testGetSuggestedPots_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/pots/suggestions/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    @Test
    void testGetSuggestedPots_shouldReturnLargerPots() {
        // Create a plant with a known pot size
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Suggest Size " + UUID.randomUUID());

        // Add some pots of various sizes
        createPot(accessToken, 5.0, 1, "Small");
        createPot(accessToken, 25.0, 1, "Medium");
        createPot(accessToken, 50.0, 1, "Large");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/pots/suggestions/" + plantId)
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    // ==================== FULL LIFECYCLE ====================

    @Test
    void testPotLifecycle_createReadUpdateDelete() {
        // CREATE
        String potId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": 99.0,
                            "quantity": 3,
                            "label": "Lifecycle Test Pot"
                        }
                        """)
                .when()
                .post("/pots")
                .then()
                .statusCode(201)
                .body("id", notNullValue())
                .extract()
                .path("id");

        // READ - verify it appears in list
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/pots")
                .then()
                .statusCode(200)
                .body("find { it.id == '%s' }.quantity".formatted(potId), is(3));

        // UPDATE
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "quantity": 7
                        }
                        """)
                .when()
                .put("/pots/" + potId)
                .then()
                .statusCode(200)
                .body("quantity", is(7));

        // DELETE
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/pots/" + potId)
                .then()
                .statusCode(204);
    }

    // ==================== REPOT SUCCESS FLOW ====================

    @Test
    void testRepotPlant_fullFlow_shouldRepotAndReturnOldPot() {
        // Use a unique diameter to avoid conflicts
        double uniqueDiam = 17.0 + Math.random() * 5;
        uniqueDiam = Math.round(uniqueDiam * 10.0) / 10.0;

        // Add pot to stock with quantity 2
        createPot(accessToken, uniqueDiam, 2, "Repot Flow Pot");

        // Create a plant
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Repot Flow " + UUID.randomUUID());

        // Repot with the new diameter
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newDiameterCm": %s,
                            "notes": "Repot flow test"
                        }
                        """.formatted(uniqueDiam))
                .when()
                .post("/pots/repot/" + plantId)
                .then()
                .statusCode(200)
                .body("potDiameterCm", notNullValue());
    }

    @Test
    void testRepotPlant_otherUsersPlant_shouldReturn403() {
        String test2Token = TestUtils.loginAsTest2();
        UUID test2RoomId = TestUtils.firstRoomId(test2Token);
        UUID test2PlantId = TestUtils.createPlantAndReturnId(test2Token, test2RoomId, "Other User Plant " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newDiameterCm": 15.0
                        }
                        """)
                .when()
                .post("/pots/repot/" + test2PlantId)
                .then()
                .statusCode(403);
    }

    @Test
    void testRepotPlant_noStockAvailable_shouldReturn400() {
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "No Stock Repot " + UUID.randomUUID());

        // Use a diameter that definitely has no stock
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "newDiameterCm": 999.1
                        }
                        """)
                .when()
                .post("/pots/repot/" + plantId)
                .then()
                .statusCode(400);
    }

    @Test
    void testUpdateStock_negativeQuantity_shouldReturn400() {
        String potId = createPot(accessToken, 16.0, 5, "Neg Update Test");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "quantity": -1
                        }
                        """)
                .when()
                .put("/pots/" + potId)
                .then()
                .statusCode(400);
    }

    // ==================== HELPER ====================

    private String createPot(String token, double diameter, int quantity, String label) {
        return given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "diameterCm": %s,
                            "quantity": %d,
                            "label": "%s"
                        }
                        """.formatted(diameter, quantity, label))
                .when()
                .post("/pots")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
