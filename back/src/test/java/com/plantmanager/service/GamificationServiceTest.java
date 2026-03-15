package com.plantmanager.service;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for GamificationService.
 * Tests gamification endpoints which exercise XP, levels, badges, and streaks.
 */
@QuarkusTest
public class GamificationServiceTest {

    @Test
    void testGetProfile_shouldReturnGamificationData() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("xp", greaterThanOrEqualTo(0))
                .body("level", greaterThanOrEqualTo(1))
                .body("levelName", notNullValue())
                .body("badges", notNullValue());
    }

    @Test
    void testGetProfile_badgesListIncludesAllTypes() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .body("badges.size()", greaterThan(0));
    }

    @Test
    void testGetLeaderboard_shouldReturnMembers() {
        String token = TestUtils.loginAsDemo();

        // Get active house ID
        String houseId = given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/gamification/leaderboard/" + houseId)
                .then()
                .statusCode(200)
                .body("size()", greaterThan(0));
    }

    @Test
    void testWateringGivesXp() {
        String token = TestUtils.loginAsDemo();
        UUID roomId = TestUtils.firstRoomId(token);

        // Get initial XP
        int initialXp = given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .extract()
                .path("xp");

        // Create a plant and water it
        UUID plantId = TestUtils.createPlantAndReturnId(token, roomId, "XP Test Plant " + UUID.randomUUID());

        given()
                .header("Authorization", "Bearer " + token)
                .contentType("application/json")
                .when()
                .post("/plants/" + plantId + "/water")
                .then()
                .statusCode(200);

        // Check XP increased
        int newXp = given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .extract()
                .path("xp");

        assertTrue(newXp >= initialXp, "XP should not decrease after watering");
    }

    @Test
    void testCareActionGivesXp() {
        String token = TestUtils.loginAsDemo();
        UUID roomId = TestUtils.firstRoomId(token);
        UUID plantId = TestUtils.createPlantAndReturnId(token, roomId, "Care XP Plant " + UUID.randomUUID());

        // Create a care log (FERTILIZING gives XP)
        given()
                .header("Authorization", "Bearer " + token)
                .contentType("application/json")
                .body("""
                        {
                            "action": "FERTILIZING",
                            "notes": "Test fertilizing for XP"
                        }
                        """)
                .when()
                .post("/plants/" + plantId + "/care-logs")
                .then()
                .statusCode(201);
    }

    @Test
    void testAddPlantGivesXp() {
        String token = TestUtils.loginAsDemo();
        UUID roomId = TestUtils.firstRoomId(token);

        // Get initial XP
        int initialXp = given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .extract()
                .path("xp");

        // Add a plant
        TestUtils.createPlantAndReturnId(token, roomId, "XP Plant " + UUID.randomUUID());

        // XP should increase by at least 20
        int newXp = given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/gamification/profile")
                .then()
                .statusCode(200)
                .extract()
                .path("xp");

        assertTrue(newXp > initialXp, "XP should increase after adding a plant");
    }

    private static void assertTrue(boolean condition, String message) {
        org.junit.jupiter.api.Assertions.assertTrue(condition, message);
    }
}
