package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for QrCodeResource endpoints.
 * Tests QR code generation for plant cards.
 */
@QuarkusTest
public class QrCodeResourceTest {

    private String accessToken;
    private UUID roomId;
    private UUID plantId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        roomId = TestUtils.firstRoomId(accessToken);
        plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "QR Plant " + UUID.randomUUID());
    }

    // ==================== GET /qrcode/plant/{plantId} ====================

    @Test
    void testGetPlantQrCode_validPlant_shouldReturn200WithPng() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .contentType("image/png")
                .header("Content-Disposition", containsString("plant-" + plantId + ".png"));
    }

    @Test
    void testGetPlantQrCode_defaultSize_shouldReturnImage() {
        byte[] imageBytes = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .extract()
                .asByteArray();

        // PNG files start with specific bytes
        assert imageBytes.length > 0;
        assert imageBytes[0] == (byte) 0x89; // PNG magic byte
        assert imageBytes[1] == (byte) 0x50; // 'P'
        assert imageBytes[2] == (byte) 0x4E; // 'N'
        assert imageBytes[3] == (byte) 0x47; // 'G'
    }

    @Test
    void testGetPlantQrCode_customSize_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("size", 500)
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .contentType("image/png");
    }

    @Test
    void testGetPlantQrCode_smallSize_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("size", 50)
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .contentType("image/png");
    }

    @Test
    void testGetPlantQrCode_maxSize_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("size", 1000)
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .contentType("image/png");
    }

    @Test
    void testGetPlantQrCode_oversizedIsCappedAt1000() {
        // Size > 1000 should be capped to 1000 (Math.min in resource)
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("size", 5000)
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .contentType("image/png");
    }

    @Test
    void testGetPlantQrCode_nonExistentPlant_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/qrcode/plant/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testGetPlantQrCode_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(401);
    }

    @Test
    void testGetPlantQrCode_invalidToken_shouldReturn401() {
        given()
                .header("Authorization", "Bearer invalid-token")
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(401);
    }

    @Test
    void testGetPlantQrCode_invalidUUID_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/qrcode/plant/not-a-uuid")
                .then()
                .statusCode(404);
    }

    @Test
    void testGetPlantQrCode_multiplePlantsGenerateDifferentQrCodes() {
        UUID plantId2 = TestUtils.createPlantAndReturnId(accessToken, roomId, "QR Plant 2 " + UUID.randomUUID());

        byte[] qr1 = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .extract()
                .asByteArray();

        byte[] qr2 = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/qrcode/plant/" + plantId2)
                .then()
                .statusCode(200)
                .extract()
                .asByteArray();

        // Different plants should produce different QR codes
        assert !java.util.Arrays.equals(qr1, qr2);
    }

    @Test
    void testGetPlantQrCode_samePlantSameSize_shouldBeConsistent() {
        byte[] qr1 = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("size", 200)
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .extract()
                .asByteArray();

        byte[] qr2 = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("size", 200)
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .extract()
                .asByteArray();

        // Same input should produce same output
        assert java.util.Arrays.equals(qr1, qr2);
    }

    @Test
    void testGetPlantQrCode_differentSizes_produceDifferentImages() {
        byte[] small = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("size", 100)
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .extract()
                .asByteArray();

        byte[] large = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("size", 800)
                .when()
                .get("/qrcode/plant/" + plantId)
                .then()
                .statusCode(200)
                .extract()
                .asByteArray();

        // Larger size should produce larger image file
        assert large.length > small.length;
    }
}
