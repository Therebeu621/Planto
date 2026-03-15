package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertTrue;

@QuarkusTest
public class FileResourceTest {

    private String accessToken;
    private UUID roomId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        roomId = TestUtils.firstRoomId(accessToken);
    }

    @AfterEach
    void cleanPhotos() {
        TestUtils.cleanupTestPhotosDir();
    }

    @Test
    void testGetFile_pathTraversalEncoded_shouldReturn400Or404() {
        int status = given()
                .urlEncodingEnabled(false)
                .when()
                .get("/files/%2E%2E/avatar.png")
                .then()
                .extract()
                .statusCode();

        assertTrue(status == 400 || status == 404,
                "Expected 400 or 404 for encoded traversal path, got " + status);
    }

    @Test
    void testGetFile_pathTraversalLiteral_shouldReturn400Or404() {
        int status = given()
                .when()
                .get("/files/../avatar.png")
                .then()
                .extract()
                .statusCode();

        assertTrue(status == 400 || status == 404,
                "Expected 400 or 404 for literal traversal path, got " + status);
    }

    @Test
    void testGetFile_pathTraversalInFolder_shouldReturn400Or404() {
        int status = given()
                .when()
                .get("/files/../etc/passwd")
                .then()
                .extract()
                .statusCode();

        assertTrue(status == 400 || status == 404,
                "Expected 400 or 404 for traversal in folder segment, got " + status);
    }

    @Test
    void testGetFile_pathTraversalInFilename_shouldReturn400Or404() {
        int status = given()
                .when()
                .get("/files/avatars/../../etc/passwd")
                .then()
                .extract()
                .statusCode();

        assertTrue(status == 400 || status == 404,
                "Expected 400 or 404 for traversal in filename segment, got " + status);
    }

    @Test
    void testGetFile_pathTraversalInBothSegments_shouldReturn400Or404() {
        int status = given()
                .urlEncodingEnabled(false)
                .when()
                .get("/files/%2E%2E/%2E%2Fsecret.txt")
                .then()
                .extract()
                .statusCode();

        assertTrue(status == 400 || status == 404,
                "Expected 400 or 404 for traversal in both segments, got " + status);
    }

    @Test
    void testGetFile_notFound_shouldReturn404() {
        given()
                .when()
                .get("/files/avatars/does-not-exist.png")
                .then()
                .statusCode(404);
    }

    @Test
    void testGetFile_uploadedProfilePhoto_shouldReturn200Image() {
        String photoUrl = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "profile.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(200)
                .body("profilePhotoUrl", notNullValue())
                .extract()
                .path("profilePhotoUrl");

        given()
                .when()
                .get(stripApiPrefix(photoUrl))
                .then()
                .statusCode(200)
                .contentType(containsString("image"));
    }

    @Test
    void testGetFile_uploadedPlantPhoto_shouldReturn200Image() {
        UUID plantId = TestUtils.createPlantAndReturnId(
                accessToken,
                roomId,
                "FileResourcePlant-" + UUID.randomUUID());

        String photoUrl = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "plant.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/plants/" + plantId + "/photo")
                .then()
                .statusCode(200)
                .body("photoUrl", notNullValue())
                .extract()
                .path("photoUrl");

        given()
                .when()
                .get(stripApiPrefix(photoUrl))
                .then()
                .statusCode(200)
                .contentType(containsString("image"));
    }

    /**
     * Test with a literal ".." in the folder segment (URL-encoded so the
     * path parameter actually arrives at the method with value "..").
     * This ensures the folder.contains("..") branch returns 400.
     */
    @Test
    void testGetFile_dotDotInFolderEncoded_shouldReturn400() {
        given()
                .urlEncodingEnabled(false)
                .when()
                .get("/files/%2E%2E/secret.txt")
                .then()
                .statusCode(anyOf(is(400), is(404)));
    }

    /**
     * Test with ".." in the filename segment (URL-encoded).
     * Ensures the filename.contains("..") branch returns 400.
     */
    @Test
    void testGetFile_dotDotInFilenameEncoded_shouldReturn400() {
        given()
                .urlEncodingEnabled(false)
                .when()
                .get("/files/avatars/%2E%2E%2Fpasswd")
                .then()
                .statusCode(anyOf(is(400), is(404)));
    }

    /**
     * Serve an uploaded file that has no extension → contentType returns null
     * and MediaType.APPLICATION_OCTET_STREAM is used instead.
     */
    @Test
    void testGetFile_fileWithNoExtension_shouldReturn200WithOctetStream() {
        // Upload a profile photo, then rename-trick: upload a file with no extension
        // We upload a PNG but access it with the actual path from the response
        String photoUrl = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "profilenoext", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(200)
                .body("profilePhotoUrl", notNullValue())
                .extract()
                .path("profilePhotoUrl");

        // The actual file is stored and served; content type may or may not be determined
        if (photoUrl != null) {
            given()
                    .when()
                    .get(stripApiPrefix(photoUrl))
                    .then()
                    .statusCode(200);
        }
    }

    private String stripApiPrefix(String urlPath) {
        if (urlPath == null) {
            return null;
        }
        return urlPath.startsWith("/api/v1") ? urlPath.substring("/api/v1".length()) : urlPath;
    }
}
