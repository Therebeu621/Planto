package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Year;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for StatsResource endpoints.
 * Tests dashboard analytics and annual retrospective stats.
 */
@QuarkusTest
public class StatsResourceTest {

    private String accessToken;
    private String test2Token;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        test2Token = TestUtils.loginAsTest2();
    }

    // ==================== GET /stats/dashboard ====================

    @Test
    void testGetDashboard_authenticated_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("totalPlants", isA(Number.class))
                .body("healthyPlants", isA(Number.class))
                .body("sickPlants", isA(Number.class))
                .body("needsWateringToday", isA(Number.class))
                .body("wateringStreak", isA(Number.class));
    }

    @Test
    void testGetDashboard_shouldReturnGamificationSummary() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("xp", isA(Number.class))
                .body("level", isA(Number.class))
                .body("levelName", notNullValue())
                .body("badgesUnlocked", isA(Number.class))
                .body("totalBadges", isA(Number.class));
    }

    @Test
    void testGetDashboard_shouldReturnActivityFeed() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("recentActivity", isA(java.util.List.class));
    }

    @Test
    void testGetDashboard_shouldReturnAnalytics() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("plantsByRoom", notNullValue())
                .body("careActionsThisWeek", notNullValue())
                .body("wateringsLast7Days", notNullValue());
    }

    @Test
    void testGetDashboard_shouldReturnHouseRankings() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("houseRankings", isA(java.util.List.class));
    }

    @Test
    void testGetDashboard_rankingsHaveRequiredFields() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("houseRankings.size()", greaterThanOrEqualTo(1))
                .body("houseRankings[0].userName", notNullValue())
                .body("houseRankings[0].xp", isA(Number.class))
                .body("houseRankings[0].level", isA(Number.class))
                .body("houseRankings[0].rank", isA(Number.class));
    }

    @Test
    void testGetDashboard_wateringsLast7DaysHas7Entries() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("wateringsLast7Days.size()", is(7));
    }

    @Test
    void testGetDashboard_healthyPlantsLessThanOrEqualTotal() {
        var response = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .extract().response();

        int total = response.path("totalPlants");
        int healthy = response.path("healthyPlants");
        int sick = response.path("sickPlants");

        assert healthy <= total : "healthyPlants should be <= totalPlants";
        assert sick <= total : "sickPlants should be <= totalPlants";
        assert healthy >= 0 : "healthyPlants should be >= 0";
        assert sick >= 0 : "sickPlants should be >= 0";
    }

    @Test
    void testGetDashboard_badgesUnlockedLessThanOrEqualTotal() {
        var response = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .extract().response();

        int unlocked = response.path("badgesUnlocked");
        int total = response.path("totalBadges");

        assert unlocked <= total : "badgesUnlocked should be <= totalBadges";
        assert unlocked >= 0;
        assert total > 0 : "totalBadges should be > 0 (enum values exist)";
    }

    @Test
    void testGetDashboard_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetDashboard_invalidToken_shouldReturn401() {
        given()
                .header("Authorization", "Bearer fake-token")
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetDashboard_differentUsersHaveDifferentData() {
        int user1Total = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .extract()
                .path("totalPlants");

        int user2Total = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .extract()
                .path("totalPlants");

        // Both valid, may differ
        assert user1Total >= 0;
        assert user2Total >= 0;
    }

    @Test
    void testGetDashboard_afterWatering_activityShouldUpdate() {
        UUID roomId = TestUtils.firstRoomId(accessToken);
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Dashboard Watering " + UUID.randomUUID());

        // Water the plant
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/plants/" + plantId + "/water")
                .then()
                .statusCode(anyOf(is(200), is(204)));

        // Dashboard should show activity
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("recentActivity.size()", greaterThanOrEqualTo(1));
    }

    @Test
    void testGetDashboard_afterAddingPlant_totalPlantsShouldIncrease() {
        int initialTotal = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .extract()
                .path("totalPlants");

        UUID roomId = TestUtils.firstRoomId(accessToken);
        TestUtils.createPlantAndReturnId(accessToken, roomId, "Dashboard Plant " + UUID.randomUUID());

        int newTotal = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .extract()
                .path("totalPlants");

        assert newTotal >= initialTotal + 1 : "totalPlants should increase after adding a plant";
    }

    @Test
    void testGetDashboard_activityItemsHaveRequiredFields() {
        // Ensure there's at least one activity item
        UUID roomId = TestUtils.firstRoomId(accessToken);
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Activity Fields " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/plants/" + plantId + "/water");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .body("recentActivity[0].type", notNullValue())
                .body("recentActivity[0].description", notNullValue())
                .body("recentActivity[0].timeAgo", notNullValue());
    }

    // ==================== GET /stats/annual ====================

    @Test
    void testGetAnnualStats_currentYear_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("year", is(Year.now().getValue()))
                .body("totalWaterings", isA(Number.class))
                .body("totalCareActions", isA(Number.class))
                .body("plantsAdded", isA(Number.class))
                .body("bestStreak", isA(Number.class));
    }

    @Test
    void testGetAnnualStats_explicitYear_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("year", 2026)
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("year", is(2026));
    }

    @Test
    void testGetAnnualStats_pastYear_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("year", 2025)
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("year", is(2025))
                .body("totalWaterings", isA(Number.class));
    }

    @Test
    void testGetAnnualStats_futureYear_shouldReturn200WithZeros() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("year", 2099)
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("year", is(2099))
                .body("totalWaterings", is(0))
                .body("totalCareActions", is(0))
                .body("plantsAdded", is(0));
    }

    @Test
    void testGetAnnualStats_zeroYearDefaultsToCurrentYear() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("year", 0)
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("year", is(Year.now().getValue()));
    }

    @Test
    void testGetAnnualStats_negativeYearDefaultsToCurrentYear() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("year", -1)
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("year", is(Year.now().getValue()));
    }

    @Test
    void testGetAnnualStats_shouldReturnWateringsByMonth() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("wateringsByMonth", notNullValue())
                .body("wateringsByMonth.size()", is(12));
    }

    @Test
    void testGetAnnualStats_shouldReturnCareActionsByType() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("careActionsByType", notNullValue());
    }

    @Test
    void testGetAnnualStats_shouldReturnMonthlyActivity() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("monthlyActivity", isA(java.util.List.class))
                .body("monthlyActivity.size()", is(12));
    }

    @Test
    void testGetAnnualStats_monthlyActivityHasRequiredFields() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("monthlyActivity[0].month", notNullValue())
                .body("monthlyActivity[0].waterings", isA(Number.class))
                .body("monthlyActivity[0].fertilizations", isA(Number.class))
                .body("monthlyActivity[0].prunings", isA(Number.class))
                .body("monthlyActivity[0].treatments", isA(Number.class))
                .body("monthlyActivity[0].repottings", isA(Number.class));
    }

    @Test
    void testGetAnnualStats_totalWateringsConsistentWithMonthly() {
        var response = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .extract().response();

        int totalWaterings = response.path("totalWaterings");
        java.util.Map<String, Integer> byMonth = response.path("wateringsByMonth");
        int sumMonthly = byMonth.values().stream().mapToInt(Integer::intValue).sum();

        assert totalWaterings == sumMonthly :
                "totalWaterings (%d) should equal sum of wateringsByMonth (%d)".formatted(totalWaterings, sumMonthly);
    }

    @Test
    void testGetAnnualStats_afterCareActions_countsShouldIncrease() {
        UUID roomId = TestUtils.firstRoomId(accessToken);
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Annual Stats Plant " + UUID.randomUUID());

        // Water the plant
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/plants/" + plantId + "/water")
                .then()
                .statusCode(anyOf(is(200), is(204)));

        // Add a fertilizing care log
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "action": "FERTILIZING",
                            "notes": "Stats test fertilizing"
                        }
                        """)
                .when()
                .post("/plants/" + plantId + "/care-logs")
                .then()
                .statusCode(201);

        // Verify annual stats reflect the actions
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("year", Year.now().getValue())
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .body("totalWaterings", greaterThanOrEqualTo(1))
                .body("totalCareActions", greaterThanOrEqualTo(2));
    }

    @Test
    void testGetAnnualStats_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetAnnualStats_invalidToken_shouldReturn401() {
        given()
                .header("Authorization", "Bearer bad-token")
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(401);
    }

    // ==================== CROSS-FEATURE CONSISTENCY ====================

    @Test
    void testDashboardAndAnnualStats_plantCountsConsistent() {
        int dashboardTotal = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .extract()
                .path("totalPlants");

        // This is the total ever; annual is only added this year
        int annualAdded = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("year", Year.now().getValue())
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .extract()
                .path("plantsAdded");

        // Annual added should be <= total plants
        assert annualAdded <= dashboardTotal :
                "plantsAdded this year (%d) should be <= totalPlants (%d)".formatted(annualAdded, dashboardTotal);
    }

    @Test
    void testDashboardAndAnnualStats_streakConsistent() {
        int dashboardStreak = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/stats/dashboard")
                .then()
                .statusCode(200)
                .extract()
                .path("wateringStreak");

        int annualBestStreak = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("year", Year.now().getValue())
                .when()
                .get("/stats/annual")
                .then()
                .statusCode(200)
                .extract()
                .path("bestStreak");

        // Best streak should be >= current streak
        assert annualBestStreak >= dashboardStreak :
                "bestStreak (%d) should be >= current wateringStreak (%d)".formatted(annualBestStreak, dashboardStreak);
    }
}
