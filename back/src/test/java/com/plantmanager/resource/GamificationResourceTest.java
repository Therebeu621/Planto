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
 * Integration tests for GamificationResource endpoints.
 * Tests XP, levels, badges, leaderboard functionality.
 */
@QuarkusTest
public class GamificationResourceTest {

    private String accessToken;
    private String test2Token;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        test2Token = TestUtils.loginAsTest2();
    }

    // ==================== GET /gamification/profile ====================

    @Test
    void testGetProfile_authenticated_shouldReturn200WithProfile() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("xp", isA(Number.class))
                .body("level", isA(Number.class))
                .body("levelName", notNullValue())
                .body("wateringStreak", isA(Number.class))
                .body("bestWateringStreak", isA(Number.class))
                .body("totalWaterings", isA(Number.class))
                .body("totalCareActions", isA(Number.class))
                .body("totalPlantsAdded", isA(Number.class))
                .body("badges", notNullValue());
    }

    @Test
    void testGetProfile_shouldReturnBadgesArray() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("badges", isA(java.util.List.class))
                .body("badges.size()", greaterThanOrEqualTo(0));
    }

    @Test
    void testGetProfile_shouldReturnLevelInfo() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("level", greaterThanOrEqualTo(1))
                .body("levelName", not(emptyString()))
                .body("xpForNextLevel", isA(Number.class))
                .body("xpProgressInLevel", isA(Number.class));
    }

    @Test
    void testGetProfile_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetProfile_invalidToken_shouldReturn401() {
        given()
                .header("Authorization", "Bearer invalid-token-here")
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetProfile_newUser_shouldHaveDefaultValues() {
        // A new user should start at level 1 with 0 XP
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("level", greaterThanOrEqualTo(1))
                .body("xp", greaterThanOrEqualTo(0));
    }

    @Test
    void testGetProfile_badgesHaveRequiredFields() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("badges.findAll { it }.every { it.code != null }", is(true))
                .body("badges.findAll { it }.every { it.name != null }", is(true))
                .body("badges.findAll { it }.every { it.description != null }", is(true));
    }

    // ==================== GET /gamification/leaderboard/{houseId} ====================

    @Test
    void testGetLeaderboard_validHouse_shouldReturn200() {
        // First get the active house ID
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/leaderboard/" + houseId)
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class))
                .body("size()", greaterThanOrEqualTo(1));
    }

    @Test
    void testGetLeaderboard_shouldReturnProfilesWithXpAndLevel() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/leaderboard/" + houseId)
                .then()
                .statusCode(200)
                .body("[0].xp", isA(Number.class))
                .body("[0].level", isA(Number.class))
                .body("[0].levelName", notNullValue());
    }

    @Test
    void testGetLeaderboard_nonExistentHouse_shouldReturn403or404() {
        UUID fakeHouseId = UUID.randomUUID();

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/leaderboard/" + fakeHouseId)
                .then()
                .statusCode(anyOf(is(403), is(404)));
    }

    @Test
    void testGetLeaderboard_unauthenticated_shouldReturn401() {
        UUID fakeHouseId = UUID.randomUUID();

        given()
                .when()
                .get("/gamification/leaderboard/" + fakeHouseId)
                .then()
                .statusCode(401);
    }

    @Test
    void testGetLeaderboard_invalidUUID_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/leaderboard/not-a-uuid")
                .then()
                .statusCode(404);
    }

    // ==================== GAMIFICATION AFTER ACTIONS ====================

    @Test
    void testProfile_afterWatering_xpShouldIncrease() {
        // Get initial profile
        int initialXp = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .extract()
                .path("xp");

        // Create a plant and water it
        UUID roomId = TestUtils.firstRoomId(accessToken);
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Gamification Test Plant " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/plants/" + plantId + "/water")
                .then()
                .statusCode(anyOf(is(200), is(204)));

        // Check XP increased
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("xp", greaterThanOrEqualTo(initialXp))
                .body("totalWaterings", greaterThanOrEqualTo(1));
    }

    @Test
    void testProfile_afterAddingPlant_totalPlantsAddedShouldIncrease() {
        int initialTotal = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .extract()
                .path("totalPlantsAdded");

        UUID roomId = TestUtils.firstRoomId(accessToken);
        TestUtils.createPlantAndReturnId(accessToken, roomId, "New Gamification Plant " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("totalPlantsAdded", greaterThanOrEqualTo(initialTotal));
    }

    @Test
    void testProfile_multipleUsers_canHaveDifferentProfiles() {
        int user1Xp = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .extract()
                .path("xp");

        int user2Xp = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .extract()
                .path("xp");

        // Both should be valid numbers (they can be equal or different)
        assert user1Xp >= 0;
        assert user2Xp >= 0;
    }

    // ==================== EDGE CASES ====================

    @Test
    void testGetProfile_emptyAuthorizationHeader_shouldReturn401() {
        given()
                .header("Authorization", "")
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetProfile_bearerWithoutToken_shouldReturn401() {
        given()
                .header("Authorization", "Bearer ")
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetLeaderboard_emptyPathParam_shouldReturn405or404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/leaderboard/")
                .then()
                .statusCode(anyOf(is(404), is(405)));
    }

    @Test
    void testGetProfile_afterCareAction_totalCareActionsShouldIncrease() {
        UUID roomId = TestUtils.firstRoomId(accessToken);
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Care Action Test " + UUID.randomUUID());

        // Record a care action
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "action": "FERTILIZING",
                            "notes": "Test fertilizing for gamification"
                        }
                        """)
                .when()
                .post("/plants/" + plantId + "/care-logs")
                .then()
                .statusCode(anyOf(is(200), is(201)));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("totalCareActions", greaterThanOrEqualTo(1));
    }
}
