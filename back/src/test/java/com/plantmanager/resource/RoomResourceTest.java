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
 * Integration tests for RoomResource.
 * Tests CRUD operations, filtering, permissions, plant associations,
 * room types, and edge cases.
 */
@QuarkusTest
public class RoomResourceTest {

    private String accessToken;
    private String test2Token;
    private String roomId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        test2Token = TestUtils.loginAsTest2();
        roomId = TestUtils.firstRoomId(accessToken).toString();
    }

    // ==================== LIST TESTS ====================

    @Test
    void testGetRooms_shouldReturnRoomsList() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .body("$", is(not(empty())))
                .body("size()", greaterThanOrEqualTo(1));
    }

    @Test
    void testGetRooms_shouldContainSalonRoom() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .body("name", hasItem("Salon"))
                .body("type", hasItem("LIVING_ROOM"));
    }

    @Test
    void testGetRooms_shouldIncludePlantsList() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .queryParam("includePlants", true)
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .body("[0].plants", is(notNullValue()));
    }

    @Test
    void testGetRooms_withIncludePlantsFalse_shouldNotIncludePlants() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .queryParam("includePlants", false)
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .body("$", is(not(empty())));
    }

    @Test
    void testGetRooms_defaultIncludePlants_shouldIncludePlants() {
        // Default is includePlants=true
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .body("[0].plants", is(notNullValue()));
    }

    @Test
    void testGetRooms_shouldContainExpectedFields() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .body("[0].id", notNullValue())
                .body("[0].name", notNullValue())
                .body("[0].type", notNullValue())
                .body("[0].createdAt", notNullValue());
    }

    @Test
    void testGetRooms_shouldIncludePlantCount() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .body("[0].plantCount", notNullValue());
    }

    @Test
    void testGetRooms_withoutAuth_shouldReturn401() {
        given()
                .when()
                .get("/rooms")
                .then()
                .statusCode(401);
    }

    // ==================== DETAIL TESTS ====================

    @Test
    void testGetRoomById_shouldReturnRoomDetails() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + roomId)
                .then()
                .statusCode(200)
                .body("id", equalTo(roomId))
                .body("name", is(notNullValue()))
                .body("type", is(notNullValue()));
    }

    @Test
    void testGetRoomById_shouldIncludePlants() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + roomId)
                .then()
                .statusCode(200)
                .body("plants", is(notNullValue()));
    }

    @Test
    void testGetRoomById_notFound_shouldReturn404() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testGetRoomById_notOwned_shouldReturn403() {
        String isolatedRoomId = createRoomInIsolatedDemoHouse();

        given()
                .header("Authorization", "Bearer " + test2Token)
                .when()
                .get("/rooms/" + isolatedRoomId)
                .then()
                .statusCode(403);
    }

    @Test
    void testGetRoomById_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/rooms/" + roomId)
                .then()
                .statusCode(401);
    }

    @Test
    void testGetRoomById_withPlants_shouldShowPlantDetails() {
        // Create a room and add a plant to it
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "PlantDetailRoom-%s",
                            "type": "BEDROOM"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "RoomDetailPlant",
                            "customSpecies": "Ficus",
                            "roomId": "%s"
                        }
                        """.formatted(tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plants", not(empty()))
                .body("plants[0].nickname", equalTo("RoomDetailPlant"))
                .body("plantCount", equalTo(1));
    }

    // ==================== CREATE TESTS ====================

    @Test
    void testCreateRoom_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Test Room",
                            "type": "OFFICE"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("name", equalTo("Test Room"))
                .body("type", equalTo("OFFICE"));
    }

    @Test
    void testCreateRoom_blankName_shouldReturn400WithCleanMessage() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "",
                            "type": "BEDROOM"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(400)
                .body("message", equalTo("Le nom de la piece est requis"));
    }

    @Test
    void testCreateRoom_livingRoom_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Living Room Test-%s",
                            "type": "LIVING_ROOM"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("type", equalTo("LIVING_ROOM"));
    }

    @Test
    void testCreateRoom_bedroom_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Bedroom Test-%s",
                            "type": "BEDROOM"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("type", equalTo("BEDROOM"));
    }

    @Test
    void testCreateRoom_balcony_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Balcony Test-%s",
                            "type": "BALCONY"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("type", equalTo("BALCONY"));
    }

    @Test
    void testCreateRoom_garden_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Garden Test-%s",
                            "type": "GARDEN"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("type", equalTo("GARDEN"));
    }

    @Test
    void testCreateRoom_kitchen_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Kitchen Test-%s",
                            "type": "KITCHEN"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("type", equalTo("KITCHEN"));
    }

    @Test
    void testCreateRoom_bathroom_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Bathroom Test-%s",
                            "type": "BATHROOM"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("type", equalTo("BATHROOM"));
    }

    @Test
    void testCreateRoom_other_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Other Test-%s",
                            "type": "OTHER"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("type", equalTo("OTHER"));
    }

    @Test
    void testCreateRoom_withoutName_shouldReturn400() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "type": "OFFICE"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateRoom_withEmptyName_shouldReturn400() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "",
                            "type": "OFFICE"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateRoom_withBlankName_shouldReturn400() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "   ",
                            "type": "OFFICE"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateRoom_withoutType_shouldReturn400() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "No Type Room"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateRoom_emptyBody_shouldReturn400() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .post("/rooms")
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateRoom_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Unauth Room",
                            "type": "OFFICE"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(401);
    }

    @Test
    void testCreateRoom_duplicateName_shouldAutoRename() {
        String baseName = "DuplicateTest-" + UUID.randomUUID();

        // Create first room
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "%s",
                            "type": "OFFICE"
                        }
                        """.formatted(baseName))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("name", equalTo(baseName));

        // Create second room with same name - should auto-rename
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "%s",
                            "type": "BEDROOM"
                        }
                        """.formatted(baseName))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("name", containsString(baseName));
    }

    @Test
    void testCreateRoom_withSpecialCharacters_shouldReturn201() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Pièce d'été #1 (2ème étage)",
                            "type": "OTHER"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("name", equalTo("Pièce d'été #1 (2ème étage)"));
    }

    @Test
    void testCreateRoom_shouldReturnIdAndCreatedAt() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Fields Room-%s",
                            "type": "OFFICE"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .body("id", notNullValue())
                .body("createdAt", notNullValue());
    }

    // ==================== UPDATE TESTS ====================

    @Test
    void testUpdateRoom_shouldReturn200() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Updated Room Name"
                        }
                        """)
                .when()
                .patch("/rooms/" + roomId)
                .then()
                .statusCode(200)
                .body("id", equalTo(roomId))
                .body("name", equalTo("Updated Room Name"));
    }

    @Test
    void testUpdateRoom_changeType_shouldReturn200() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "TypeChange-%s",
                            "type": "OFFICE"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "type": "BEDROOM"
                        }
                        """)
                .when()
                .patch("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("type", equalTo("BEDROOM"));
    }

    @Test
    void testUpdateRoom_changeNameAndType_shouldReturn200() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "BothChange-%s",
                            "type": "OFFICE"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "New Name",
                            "type": "GARDEN"
                        }
                        """)
                .when()
                .patch("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("name", equalTo("New Name"))
                .body("type", equalTo("GARDEN"));
    }

    @Test
    void testUpdateRoom_namePersistsAfterUpdate() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "PersistCheck-%s",
                            "type": "OFFICE"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Persisted Name"
                        }
                        """)
                .when()
                .patch("/rooms/" + tempRoomId)
                .then()
                .statusCode(200);

        // Verify persistence
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("name", equalTo("Persisted Name"));
    }

    @Test
    void testUpdateRoom_notOwned_shouldReturn403() {
        String isolatedRoomId = createRoomInIsolatedDemoHouse();

        given()
                .header("Authorization", "Bearer " + test2Token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Hacked Name"
                        }
                        """)
                .when()
                .patch("/rooms/" + isolatedRoomId)
                .then()
                .statusCode(403);
    }

    @Test
    void testUpdateRoom_notFound_shouldReturn404() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Ghost Room"
                        }
                        """)
                .when()
                .patch("/rooms/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testUpdateRoom_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Unauth Update"
                        }
                        """)
                .when()
                .patch("/rooms/" + roomId)
                .then()
                .statusCode(401);
    }

    // ==================== DELETE TESTS ====================

    @Test
    void testDeleteRoom_shouldReturn204() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Delete Me",
                            "type": "OFFICE"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .delete("/rooms/" + tempRoomId)
                .then()
                .statusCode(204);
    }

    @Test
    void testDeleteRoom_verifyGone_shouldReturn404() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Delete Verify-%s",
                            "type": "OFFICE"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .delete("/rooms/" + tempRoomId)
                .then()
                .statusCode(204);

        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteRoom_alreadyDeleted_shouldReturn404() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "DoubleDelete-%s",
                            "type": "OFFICE"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .delete("/rooms/" + tempRoomId)
                .then()
                .statusCode(204);

        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .delete("/rooms/" + tempRoomId)
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteRoom_notOwned_shouldReturn403() {
        String isolatedRoomId = createRoomInIsolatedDemoHouse();

        given()
                .header("Authorization", "Bearer " + test2Token)
                .when()
                .delete("/rooms/" + isolatedRoomId)
                .then()
                .statusCode(403);
    }

    @Test
    void testDeleteRoom_notFound_shouldReturn404() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .delete("/rooms/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteRoom_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/rooms/" + roomId)
                .then()
                .statusCode(401);
    }

    @Test
    void testDeleteRoom_shouldNotAffectOtherRooms() {
        String roomToKeep = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "KeepRoom-%s",
                            "type": "BEDROOM"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String roomToDelete = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "DeleteRoom-%s",
                            "type": "OFFICE"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .delete("/rooms/" + roomToDelete)
                .then()
                .statusCode(204);

        // Other room should still exist
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + roomToKeep)
                .then()
                .statusCode(200);
    }

    // ==================== PLANT ASSOCIATION TESTS ====================

    @Test
    void testDeleteRoom_withPlant_shouldKeepPlantAndSetRoomToNull() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Plant Room",
                            "type": "OFFICE"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "RoomDeletePlant",
                            "customSpecies": "Monstera deliciosa",
                            "roomId": "%s"
                        }
                        """.formatted(tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .delete("/rooms/" + tempRoomId)
                .then()
                .statusCode(204);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId)
                .then()
                .statusCode(200)
                .body("id", equalTo(plantId))
                .body("room", nullValue());
    }

    @Test
    void testDeleteRoom_withMultiplePlants_shouldOrphanAll() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "MultiPlantRoom-%s",
                            "type": "GARDEN"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Create 3 plants in the room
        String plantId1 = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Orphan1-%s",
                            "customSpecies": "Fern",
                            "roomId": "%s"
                        }
                        """.formatted(UUID.randomUUID(), tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String plantId2 = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Orphan2-%s",
                            "customSpecies": "Cactus",
                            "roomId": "%s"
                        }
                        """.formatted(UUID.randomUUID(), tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String plantId3 = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Orphan3-%s",
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

        // Delete room
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .delete("/rooms/" + tempRoomId)
                .then()
                .statusCode(204);

        // All 3 plants should still exist with null room
        for (String pId : new String[]{plantId1, plantId2, plantId3}) {
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .when()
                    .get("/plants/" + pId)
                    .then()
                    .statusCode(200)
                    .body("room", nullValue());
        }
    }

    @Test
    void testRoomPlantCount_shouldReflectAddedPlants() {
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "CountRoom-%s",
                            "type": "BEDROOM"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Room should start empty
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plantCount", equalTo(0));

        // Add a plant
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "CountPlant",
                            "customSpecies": "Fern",
                            "roomId": "%s"
                        }
                        """.formatted(tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        // Count should be 1
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + tempRoomId)
                .then()
                .statusCode(200)
                .body("plantCount", equalTo(1));
    }

    @Test
    void testMovePlantBetweenRooms_shouldUpdateBothRooms() {
        // Create two rooms
        String roomA = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "RoomA-%s",
                            "type": "BEDROOM"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String roomB = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "RoomB-%s",
                            "type": "KITCHEN"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Create plant in room A
        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "MovingPlant-%s",
                            "customSpecies": "Basil",
                            "roomId": "%s"
                        }
                        """.formatted(UUID.randomUUID(), roomA))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Move plant to room B
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

        // Verify room B has the plant
        given()
                .header("Authorization", "Bearer " + accessToken)
                .when()
                .get("/rooms/" + roomB)
                .then()
                .statusCode(200)
                .body("plantCount", equalTo(1));
    }

    @Test
    void testFilterPlantsByRoom_shouldOnlyReturnRoomPlants() {
        // Create a room with a known plant
        String tempRoomId = given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "FilterRoom-%s",
                            "type": "BALCONY"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String uniqueName = "FilterRoomPlant-" + UUID.randomUUID();
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "Orchid",
                            "roomId": "%s"
                        }
                        """.formatted(uniqueName, tempRoomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        // Filter by this room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("roomId", tempRoomId)
                .when()
                .get("/plants")
                .then()
                .statusCode(200)
                .body("nickname", hasItem(uniqueName));
    }

    // ==================== HELPER ====================

    private String createRoomInIsolatedDemoHouse() {
        given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Isolated House %s"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/houses")
                .then()
                .statusCode(201);

        return given()
                .header("Authorization", "Bearer " + accessToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Isolated Room",
                            "type": "OFFICE"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
