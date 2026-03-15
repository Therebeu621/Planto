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
 * Cross-cutting integration tests for Plant-Room associations.
 * Tests the relationship between plants and rooms: assignment, movement,
 * orphaning, multi-room scenarios, health tracking across rooms, and edge cases.
 */
@QuarkusTest
public class PlantRoomAssociationTest {

    private String accessToken;
    private String test2Token;
    private UUID defaultRoomId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        test2Token = TestUtils.loginAsTest2();
        defaultRoomId = TestUtils.firstRoomId(accessToken);
    }

    // ==================== PLANT CREATION WITH ROOM ====================

    @Test
    void testCreatePlantInRoom_shouldAppearInRoomDetail() {
        String tempRoomId = createRoom("AppearRoom-" + UUID.randomUUID(), "BEDROOM");
        String uniqueName = "AppearPlant-" + UUID.randomUUID();

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "Fern",
                            "roomId": "%s"
                        }
                        """.formatted(uniqueName, tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plants.nickname", hasItem(uniqueName))
                .body("plantCount", equalTo(1));
    }

    @Test
    void testCreatePlantWithoutRoom_shouldNotAppearInAnyRoom() {
        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Homeless-%s",
                            "customSpecies": "Cactus"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .body("roomId", nullValue())
                .extract()
                .path("id");

        // Verify plant detail shows no room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId)
                .then()
                .statusCode(200)
                .body("room", nullValue());
    }

    // ==================== PLANT MOVEMENT BETWEEN ROOMS ====================

    @Test
    void testMovePlant_fromOneRoomToAnother_shouldUpdateBoth() {
        String roomA = createRoom("MoveFromA-" + UUID.randomUUID(), "BEDROOM");
        String roomB = createRoom("MoveToB-" + UUID.randomUUID(), "KITCHEN");

        // Create plant in room A
        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Mover-%s",
                            "customSpecies": "Pothos",
                            "roomId": "%s"
                        }
                        """.formatted(UUID.randomUUID(), roomA))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Move to room B
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "roomId": "%s"
                        }
                        """.formatted(roomB))
                .when()
                .put("/plants/" + plantId)
                .then()
                .statusCode(200)
                .body("roomId", equalTo(roomB));

        // Room A should have 0 plants
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms/" + roomA)
                .then()
                .statusCode(200)
                .body("plantCount", equalTo(0));

        // Room B should have the plant
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms/" + roomB)
                .then()
                .statusCode(200)
                .body("plantCount", equalTo(1));
    }

    @Test
    void testMovePlant_fromRoomToNoRoom_keepsPreviousRoom() {
        // Note: partial update with null roomId does NOT unassign the room (null = "don't change")
        String tempRoomId = createRoom("OrphanFrom-" + UUID.randomUUID(), "BALCONY");

        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Orphanable-%s",
                            "customSpecies": "Rose",
                            "roomId": "%s"
                        }
                        """.formatted(UUID.randomUUID(), tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Update with null roomId - room stays unchanged (partial update semantics)
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "roomId": null
                        }
                        """)
                .when()
                .put("/plants/" + plantId)
                .then()
                .statusCode(200)
                .body("roomId", equalTo(tempRoomId));
    }

    @Test
    void testAssignOrphanPlant_toRoom_shouldWork() {
        // Create plant without room
        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Assignable-%s",
                            "customSpecies": "Basil"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .body("roomId", nullValue())
                .extract()
                .path("id");

        // Assign to a room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "roomId": "%s"
                        }
                        """.formatted(defaultRoomId))
                .when()
                .put("/plants/" + plantId)
                .then()
                .statusCode(200)
                .body("roomId", equalTo(defaultRoomId.toString()));
    }

    @Test
    void testMovePlant_backAndForth_shouldWork() {
        String roomA = createRoom("BackForthA-" + UUID.randomUUID(), "BEDROOM");
        String roomB = createRoom("BackForthB-" + UUID.randomUUID(), "KITCHEN");

        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "BackForth-%s",
                            "customSpecies": "Mint",
                            "roomId": "%s"
                        }
                        """.formatted(UUID.randomUUID(), roomA))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Move A → B
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {"roomId": "%s"}
                        """.formatted(roomB))
                .when()
                .put("/plants/" + plantId)
                .then()
                .statusCode(200);

        // Move B → A
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {"roomId": "%s"}
                        """.formatted(roomA))
                .when()
                .put("/plants/" + plantId)
                .then()
                .statusCode(200)
                .body("roomId", equalTo(roomA));
    }

    // ==================== MULTIPLE PLANTS IN ONE ROOM ====================

    @Test
    void testMultiplePlantsInRoom_shouldAllAppear() {
        String tempRoomId = createRoom("MultiRoom-" + UUID.randomUUID(), "GARDEN");

        String name1 = "Multi1-" + UUID.randomUUID();
        String name2 = "Multi2-" + UUID.randomUUID();
        String name3 = "Multi3-" + UUID.randomUUID();

        createPlantInRoom(name1, tempRoomId);
        createPlantInRoom(name2, tempRoomId);
        createPlantInRoom(name3, tempRoomId);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plantCount", equalTo(3))
                .body("plants", hasSize(3))
                .body("plants.nickname", hasItems(name1, name2, name3));
    }

    @Test
    void testDeleteOnePlantFromRoom_shouldKeepOthers() {
        String tempRoomId = createRoom("DeleteOneRoom-" + UUID.randomUUID(), "OFFICE");

        createPlantInRoom("Keep1-" + UUID.randomUUID(), tempRoomId);
        String deletePlantId = createPlantInRoom("DeleteMe-" + UUID.randomUUID(), tempRoomId);
        createPlantInRoom("Keep2-" + UUID.randomUUID(), tempRoomId);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/plants/" + deletePlantId)
                .then()
                .statusCode(204);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plantCount", equalTo(2));
    }

    // ==================== PLANT HEALTH ACROSS ROOMS ====================

    @Test
    void testSickPlantInRoom_shouldShowInRoomDetail() {
        String tempRoomId = createRoom("SickRoom-" + UUID.randomUUID(), "BATHROOM");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "SickInRoom-%s",
                            "customSpecies": "Orchid",
                            "roomId": "%s",
                            "isSick": true
                        }
                        """.formatted(UUID.randomUUID(), tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plants[0].isSick", equalTo(true));
    }

    @Test
    void testWaterPlantInRoom_shouldUpdatePlantState() {
        String tempRoomId = createRoom("WaterRoom-" + UUID.randomUUID(), "BALCONY");
        String plantId = createPlantInRoom("WaterMe-" + UUID.randomUUID(), tempRoomId);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/plants/" + plantId + "/water")
                .then()
                .statusCode(200)
                .body("lastWatered", notNullValue())
                .body("nextWateringDate", notNullValue());

        // Verify in room detail
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plants[0].nextWateringDate", notNullValue());
    }

    // ==================== FULL LIFECYCLE TESTS ====================

    @Test
    void testPlantFullLifecycle_createWaterUpdateDelete() {
        String tempRoomId = createRoom("LifecycleRoom-" + UUID.randomUUID(), "GARDEN");

        // 1. Create
        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Lifecycle Plant",
                            "customSpecies": "Monstera",
                            "roomId": "%s",
                            "wateringIntervalDays": 7,
                            "exposure": "PARTIAL_SHADE",
                            "notes": "Just bought"
                        }
                        """.formatted(tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .body("nickname", equalTo("Lifecycle Plant"))
                .extract()
                .path("id");

        // 2. Water
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/plants/" + plantId + "/water")
                .then()
                .statusCode(200)
                .body("lastWatered", notNullValue());

        // 3. Add care log
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "action": "FERTILIZING",
                            "notes": "Monthly fertilizer"
                        }
                        """)
                .when()
                .post("/plants/" + plantId + "/care-logs")
                .then()
                .statusCode(201);

        // 4. Update health
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Lifecycle Plant (updated)",
                            "notes": "Growing well, moved to sun",
                            "exposure": "SUN",
                            "isSick": false,
                            "isWilted": false
                        }
                        """)
                .when()
                .put("/plants/" + plantId)
                .then()
                .statusCode(200)
                .body("nickname", equalTo("Lifecycle Plant (updated)"))
                .body("exposure", equalTo("SUN"));

        // 5. Upload photo
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "plant.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photo")
                .then()
                .statusCode(200)
                .body("photoUrl", notNullValue());

        // 6. Verify full detail
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId)
                .then()
                .statusCode(200)
                .body("nickname", equalTo("Lifecycle Plant (updated)"))
                .body("exposure", equalTo("SUN"))
                .body("recentCareLogs", not(empty()))
                .body("room", notNullValue());

        // 7. Delete
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/plants/" + plantId)
                .then()
                .statusCode(204);

        // 8. Verify gone
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId)
                .then()
                .statusCode(404);
    }

    @Test
    void testRoomFullLifecycle_createAddPlantsUpdateDelete() {
        // 1. Create room
        String tempRoomId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Lifecycle Room",
                            "type": "BALCONY"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("name", equalTo("Lifecycle Room"))
                .body("type", equalTo("BALCONY"))
                .extract()
                .path("id");

        // 2. Add plants
        String plantId1 = createPlantInRoom("LC-Plant1-" + UUID.randomUUID(), tempRoomId);
        String plantId2 = createPlantInRoom("LC-Plant2-" + UUID.randomUUID(), tempRoomId);

        // 3. Verify room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plantCount", equalTo(2));

        // 4. Update room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Lifecycle Room (renovated)",
                            "type": "GARDEN"
                        }
                        """)
                .when()
                .patch("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("name", equalTo("Lifecycle Room (renovated)"))
                .body("type", equalTo("GARDEN"));

        // 5. Delete room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/rooms/" + tempRoomId)
                .then()
                .statusCode(204);

        // 6. Plants should be orphaned but exist
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId1)
                .then()
                .statusCode(200)
                .body("room", nullValue());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId2)
                .then()
                .statusCode(200)
                .body("room", nullValue());
    }

    // ==================== PERMISSION EDGE CASES ====================

    @Test
    void testUser2CannotMovePlantToUser1Room() {
        // Force user2 into an isolated house to guarantee cross-house behavior
        String test2RoomId = createIsolatedRoomForToken(test2Token);
        UUID test2PlantId = TestUtils.createPlantAndReturnId(test2Token,
                UUID.fromString(test2RoomId), "Test2Plant-" + UUID.randomUUID());

        // Test2 cannot move plant to user1's room - returns 403 (access denied)
        int status = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "roomId": "%s"
                        }
                        """.formatted(defaultRoomId))
                .when()
                .put("/plants/" + test2PlantId)
                .then()
                .extract()
                .statusCode();

        org.junit.jupiter.api.Assertions.assertTrue(
                status == 403 || status == 404,
                "Expected 403 or 404 for cross-user room move, got " + status);
    }

    @Test
    void testUser2CannotCreatePlantInUser1Room() {
        // Force user2 into an isolated house to guarantee cross-house behavior
        createIsolatedRoomForToken(test2Token);

        // Returns 403 (room belongs to another house)
        int status = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Intruder Plant",
                            "customSpecies": "Cactus",
                            "roomId": "%s"
                        }
                        """.formatted(defaultRoomId))
                .when()
                .post("/plants")
                .then()
                .extract()
                .statusCode();

        org.junit.jupiter.api.Assertions.assertTrue(
                status == 403 || status == 404,
                "Expected 403 or 404 for cross-user plant creation, got " + status);
    }

    // ==================== HELPERS ====================

    private String createRoom(String name, String type) {
        return given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "%s",
                            "type": "%s"
                        }
                        """.formatted(name, type))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    private String createPlantInRoom(String nickname, String roomId) {
        return given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "Generic Plant",
                            "roomId": "%s"
                        }
                        """.formatted(nickname, roomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    private String createIsolatedRoomForToken(String token) {
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "IsolatedHouse-%s"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/houses")
                .then()
                .statusCode(201);

        return given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "IsolatedRoom-%s",
                            "type": "LIVING_ROOM"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
