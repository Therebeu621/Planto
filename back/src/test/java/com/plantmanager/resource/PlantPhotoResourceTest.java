package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for PlantPhotoResource endpoints.
 * Tests multi-photo gallery: upload, list, set primary, delete.
 */
@QuarkusTest
public class PlantPhotoResourceTest {

    private String accessToken;
    private UUID roomId;
    private UUID plantId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        roomId = TestUtils.firstRoomId(accessToken);
        plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Photo Gallery Plant " + UUID.randomUUID());
    }

    @AfterEach
    void cleanPhotos() {
        TestUtils.cleanupTestPhotosDir();
    }

    // ==================== GET /plants/{plantId}/photos ====================

    @Test
    void testGetPhotos_emptyGallery_shouldReturn200WithEmptyList() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId + "/photos")
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetPhotos_nonExistentPlant_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + UUID.randomUUID() + "/photos")
                .then()
                .statusCode(404);
    }

    @Test
    void testGetPhotos_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/plants/" + plantId + "/photos")
                .then()
                .statusCode(401);
    }

    // ==================== POST /plants/{plantId}/photos ====================

    @Test
    void testAddPhoto_validPng_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "plant.png", TestUtils.minimalPngBytes(), "image/png")
                .multiPart("caption", "Vue de face")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201)
                .body("id", notNullValue())
                .body("caption", equalTo("Vue de face"))
                .body("photoUrl", notNullValue());
    }

    @Test
    void testAddPhoto_withoutCaption_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "plant.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201)
                .body("id", notNullValue());
    }

    @Test
    void testAddPhoto_firstPhotoBecomePrimary() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "first.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201)
                .body("isPrimary", is(true));
    }

    @Test
    void testAddPhoto_markAsPrimary_shouldSetPrimary() {
        // Add first photo (auto-primary)
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "first.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201);

        // Add second photo as primary
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "second.png", TestUtils.minimalPngBytes(), "image/png")
                .multiPart("isPrimary", "true")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201)
                .body("isPrimary", is(true));
    }

    @Test
    void testAddPhoto_noFile_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("caption", "No file")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(400);
    }

    @Test
    void testAddPhoto_invalidMimeType_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "doc.txt", "not an image".getBytes(StandardCharsets.UTF_8), "text/plain")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(400);
    }

    @Test
    void testAddPhoto_nonExistentPlant_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "photo.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + UUID.randomUUID() + "/photos")
                .then()
                .statusCode(404);
    }

    @Test
    void testAddPhoto_unauthenticated_shouldReturn401() {
        given()
                .multiPart("file", "photo.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(401);
    }

    // ==================== PUT /plants/{plantId}/photos/{photoId}/primary ====================

    @Test
    void testSetPrimary_existingPhoto_shouldReturn200() {
        // Add two photos
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "first.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201);

        String secondPhotoId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "second.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Set second as primary
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .put("/plants/" + plantId + "/photos/" + secondPhotoId + "/primary")
                .then()
                .statusCode(200)
                .body("isPrimary", is(true));
    }

    @Test
    void testSetPrimary_nonExistentPhoto_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .put("/plants/" + plantId + "/photos/" + UUID.randomUUID() + "/primary")
                .then()
                .statusCode(404);
    }

    @Test
    void testSetPrimary_unauthenticated_shouldReturn401() {
        given()
                .when()
                .put("/plants/" + plantId + "/photos/" + UUID.randomUUID() + "/primary")
                .then()
                .statusCode(401);
    }

    // ==================== DELETE /plants/{plantId}/photos/{photoId} ====================

    @Test
    void testDeletePhoto_existing_shouldReturn204() {
        String photoId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "delete-me.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/plants/" + plantId + "/photos/" + photoId)
                .then()
                .statusCode(204);
    }

    @Test
    void testDeletePhoto_primaryPhoto_shouldPromoteNext() {
        // Add two photos
        String firstPhotoId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "primary.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "secondary.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201);

        // Delete primary
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/plants/" + plantId + "/photos/" + firstPhotoId)
                .then()
                .statusCode(204);

        // Remaining photo should become primary
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId + "/photos")
                .then()
                .statusCode(200)
                .body("size()", is(1))
                .body("[0].isPrimary", is(true));
    }

    @Test
    void testDeletePhoto_nonExistentPhoto_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/plants/" + plantId + "/photos/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testDeletePhoto_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/plants/" + plantId + "/photos/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    // ==================== FULL LIFECYCLE ====================

    @Test
    void testPhotoGalleryLifecycle() {
        // Upload 3 photos
        uploadPhoto("photo1.png", "Vue de face");
        String photo2Id = uploadPhoto("photo2.png", "Vue de cote");
        String photo3Id = uploadPhoto("photo3.png", "Gros plan");

        // List should return 3
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId + "/photos")
                .then()
                .statusCode(200)
                .body("size()", is(3));

        // Set photo3 as primary
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .put("/plants/" + plantId + "/photos/" + photo3Id + "/primary")
                .then()
                .statusCode(200)
                .body("isPrimary", is(true));

        // Delete photo2
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/plants/" + plantId + "/photos/" + photo2Id)
                .then()
                .statusCode(204);

        // List should return 2
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants/" + plantId + "/photos")
                .then()
                .statusCode(200)
                .body("size()", is(2));
    }

    // ==================== HELPER ====================

    private String uploadPhoto(String filename, String caption) {
        var builder = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", filename, TestUtils.minimalPngBytes(), "image/png");

        if (caption != null) {
            builder = builder.multiPart("caption", caption);
        }

        return builder
                .when()
                .post("/plants/" + plantId + "/photos")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
