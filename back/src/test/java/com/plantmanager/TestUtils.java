package com.plantmanager;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.RestAssured;
import io.restassured.http.ContentType;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Utility class for integration tests.
 * Provides helper methods and constants for test data.
 */
public class TestUtils {
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final Path TEST_PHOTOS_DIR = Path.of("target", "test-photos");

    // ==================== DYNAMIC TEST USER (unique per test run) ====================
    
    /** Unique suffix to avoid conflicts between test runs */
    private static final String TEST_RUN_ID = java.util.UUID.randomUUID().toString().substring(0, 8);
    
    /** Main test user - created fresh each test run */
    public static final String DEMO_EMAIL = "testuser" + TEST_RUN_ID + "@test.com";
    public static final String DEMO_PASSWORD = "password123";
    
    /** Test user 2 - created fresh each test run */
    public static final String TEST2_EMAIL = "testuser2" + TEST_RUN_ID + "@test.com";
    public static final String TEST2_PASSWORD = "password123";

    /** Demo house shared by all test users */
    public static final UUID DEMO_HOUSE_ID = UUID.fromString("11111111-1111-1111-1111-111111111111");
    public static final String DEMO_HOUSE_CODE = "DEMO1234";

    /** Demo rooms for testing */
    public static final String DEMO_ROOM_SALON = "Salon";
    public static final String DEMO_ROOM_BALCON = "Balcon";
    public static final String DEMO_ROOM_CHAMBRE = "Chambre";

    /**
     * Login as demo user and return access token.
     * If user doesn't exist, create it first via register.
     *
     * @return the access token for the test user
     */
    public static String loginAsDemo() {
        return getOrCreateUserToken(DEMO_EMAIL, DEMO_PASSWORD, "Test Demo User");
    }

    /**
     * Login as test user 2 and return access token.
     *
     * @return the access token for test2@example.com
     */
    public static String loginAsTest2() {
        return getOrCreateUserToken(TEST2_EMAIL, TEST2_PASSWORD, "Test User 2");
    }

    /**
     * Try to login, if it fails with 401 (user doesn't exist or wrong password),
     * create the user via register first, then login.
     */
    private static String getOrCreateUserToken(String email, String password, String displayName) {
        String token = null;

        // First try to login
        io.restassured.response.Response loginResponse = RestAssured.given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """.formatted(email, password))
                .when()
                .post("/auth/login");
        
        if (loginResponse.statusCode() == 200) {
            token = loginResponse.path("accessToken");
        } else {
            // If login failed, try to register the user first
            io.restassured.response.Response registerResponse = RestAssured.given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "email": "%s",
                                "password": "%s",
                                "displayName": "%s"
                            }
                            """.formatted(email, password, displayName))
                    .when()
                    .post("/auth/register");
            
            // If register succeeded (201) or user already exists (409), try login again
            if (registerResponse.statusCode() == 201) {
                token = registerResponse.path("accessToken");
            } else {
                // Final attempt to login
                token = RestAssured.given()
                        .contentType(ContentType.JSON)
                        .body("""
                                {
                                    "email": "%s",
                                    "password": "%s"
                                }
                                """.formatted(email, password))
                        .when()
                        .post("/auth/login")
                        .then()
                        .statusCode(200)
                        .extract()
                        .path("accessToken");
            }
        }

        // Ensure user has a house (required for most tests)
        ensureUserHasHouse(token);
        
        return token;
    }

    private static void ensureUserHasHouse(String token) {
        String activeHouseId = ensureActiveHouse(token);

        // Ensure user has at least one room (required for Plant tests).
        io.restassured.response.Response roomsResponse = RestAssured.given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/rooms");

        if (roomsResponse.statusCode() != 200) {
            return;
        }

        List<Object> rooms = roomsResponse.jsonPath().getList("$");
        if (rooms != null && !rooms.isEmpty()) {
            return;
        }

        io.restassured.response.Response createRoomResponse = RestAssured.given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Salon",
                            "type": "LIVING_ROOM"
                        }
                        """)
                .when()
                .post("/rooms");

        if (createRoomResponse.statusCode() == 403 && activeHouseId != null) {
            // Defensive fallback for runs where memberships exist but no active house remains.
            RestAssured.given()
                    .header("Authorization", "Bearer " + token)
                    .when()
                    .put("/houses/" + activeHouseId + "/activate");

            RestAssured.given()
                    .header("Authorization", "Bearer " + token)
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "name": "Salon",
                                "type": "LIVING_ROOM"
                            }
                            """)
                    .when()
                    .post("/rooms");
        }
    }

    private static String ensureActiveHouse(String token) {
        io.restassured.response.Response activeHouseResponse = RestAssured.given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/active");

        if (activeHouseResponse.statusCode() == 200) {
            return activeHouseResponse.path("id");
        }

        io.restassured.response.Response housesResponse = RestAssured.given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses");

        if (housesResponse.statusCode() != 200) {
            return null;
        }

        List<Object> houses = housesResponse.jsonPath().getList("$");
        if (houses == null || houses.isEmpty()) {
            io.restassured.response.Response createHouseResponse = RestAssured.given()
                    .header("Authorization", "Bearer " + token)
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "name": "Default Test House"
                            }
                            """)
                    .when()
                    .post("/houses");
            if (createHouseResponse.statusCode() == 201) {
                return createHouseResponse.path("id");
            }
            return null;
        }

        String firstHouseId = extractFirstHouseId(houses);
        if (firstHouseId == null) {
            return null;
        }

        io.restassured.response.Response activateResponse = RestAssured.given()
                .header("Authorization", "Bearer " + token)
                .when()
                .put("/houses/" + firstHouseId + "/activate");

        if (activateResponse.statusCode() == 200) {
            return firstHouseId;
        }

        return null;
    }

    private static String extractFirstHouseId(List<Object> houses) {
        Object first = houses.get(0);
        if (!(first instanceof Map<?, ?> map)) {
            return null;
        }
        Object id = map.get("id");
        return id == null ? null : id.toString();
    }

    /**
     * Create authorization header from access token.
     *
     * @param token the access token
     * @return Authorization header value
     */
    public static String authHeader(String token) {
        return "Bearer " + token;
    }

    /**
     * Return the first room id for the authenticated user.
     */
    public static UUID firstRoomId(String token) {
        String roomIdStr = RestAssured.given()
                .header("Authorization", authHeader(token))
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].id");
        return UUID.fromString(roomIdStr);
    }

    /**
     * Create a plant and return its id.
     */
    public static UUID createPlantAndReturnId(String token, UUID roomId, String nickname) {
        String plantIdStr = RestAssured.given()
                .header("Authorization", authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "Monstera deliciosa",
                            "roomId": "%s"
                        }
                        """.formatted(nickname, roomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
        return UUID.fromString(plantIdStr);
    }

    /**
     * Build a fake Google ID token payload for tests.
     * Format: header.payload.signature (unsigned, local decoding only).
     */
    public static String buildGoogleIdToken(Map<String, Object> payload) {
        String headerJson = "{\"alg\":\"none\",\"typ\":\"JWT\"}";
        String payloadJson;
        try {
            payloadJson = MAPPER.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Failed to encode payload JSON", e);
        }

        Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
        String header = encoder.encodeToString(headerJson.getBytes(StandardCharsets.UTF_8));
        String body = encoder.encodeToString(payloadJson.getBytes(StandardCharsets.UTF_8));
        return header + "." + body + ".signature";
    }

    /**
     * Minimal valid PNG (1x1) for multipart upload tests.
     */
    public static byte[] minimalPngBytes() {
        return Base64.getDecoder().decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/a9kAAAAASUVORK5CYII=");
    }

    /**
     * Cleanup uploaded test files from isolated photo directory.
     */
    public static void cleanupTestPhotosDir() {
        if (!Files.exists(TEST_PHOTOS_DIR)) {
            return;
        }
        try (var walk = Files.walk(TEST_PHOTOS_DIR)) {
            walk.sorted(Comparator.reverseOrder()).forEach(path -> {
                try {
                    Files.deleteIfExists(path);
                } catch (IOException ignored) {
                    // Best effort cleanup for test artifacts
                }
            });
        } catch (IOException ignored) {
            // Best effort cleanup for test artifacts
        }
    }
}
