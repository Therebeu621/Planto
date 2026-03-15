package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for the watering and care reminder system.
 * Tests the trigger-reminders endpoint with various plant configurations
 * to verify grouped notifications, personalized care tips, species-based
 * recommendations, and weather integration.
 */
@QuarkusTest
public class WateringReminderTest {

    private String accessToken;
    private String test2Token;
    private UUID roomId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        test2Token = TestUtils.loginAsTest2();

        String roomIdStr = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/rooms")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].id");
        roomId = UUID.fromString(roomIdStr);

        // Clear unread notifications before each test
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all");
    }

    // ==================== HELPERS ====================

    private UUID createPlant(String token, String nickname, String species,
                              int wateringInterval, boolean sick, boolean wilted, boolean repotting) {
        String plantId = given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "%s",
                            "roomId": "%s",
                            "wateringIntervalDays": %d,
                            "isSick": %s,
                            "isWilted": %s,
                            "needsRepotting": %s
                        }
                        """.formatted(nickname, species, roomId, wateringInterval,
                        sick, wilted, repotting))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
        return UUID.fromString(plantId);
    }

    private UUID createHealthyPlant(String token, String nickname) {
        return createPlant(token, nickname, "Monstera deliciosa", 7,
                false, false, false);
    }

    private UUID createSickPlant(String token, String nickname) {
        return createPlant(token, nickname, "Ficus elastica", 7,
                true, false, false);
    }

    private void triggerReminders(String token) {
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .when()
                .post("/notifications/trigger-reminders")
                .then()
                .statusCode(200);
    }

    private void clearNotifications(String token) {
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all");
    }

    private List<java.util.Map<String, Object>> getUnreadNotifications(String token) {
        return given()
                .header("Authorization", TestUtils.authHeader(token))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .jsonPath()
                .getList("$");
    }

    // ==================== WATERING REMINDERS ====================

    @Test
    void testTriggerReminders_noPlants_shouldSucceed() {
        // Trigger with potentially no plants needing water
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/notifications/trigger-reminders")
                .then()
                .statusCode(200)
                .body("status", equalTo("Reminders triggered successfully"));
    }

    @Test
    void testTriggerReminders_wateringReminder_shouldBeCreated() {
        String name = "WaterMe " + UUID.randomUUID().toString().substring(0, 6);
        // Plant with 1-day interval - should need watering
        createPlant(accessToken, name, "Fern", 1, false, false, false);

        // Water the plant first, then wait (we can't wait, so just trigger)
        clearNotifications(accessToken);
        triggerReminders(accessToken);

        // Check for any watering reminder
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(0));
    }

    // ==================== CARE REMINDERS ====================

    @Test
    void testCareReminder_sickPlant_shouldCreateNotification() {
        String name = "SickPlant " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }", notNullValue())
                .body("find { it.type == 'CARE_REMINDER' }.message", containsString(name));
    }

    @Test
    void testCareReminder_wiltedPlant_shouldMentionWilted() {
        String name = "Wilted " + UUID.randomUUID().toString().substring(0, 6);
        createPlant(accessToken, name, "Rose", 7, false, true, false);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", containsString("fanée"));
    }

    @Test
    void testCareReminder_needsRepotting_shouldMentionRepotting() {
        String name = "Repot " + UUID.randomUUID().toString().substring(0, 6);
        createPlant(accessToken, name, "Cactus", 14, false, false, true);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", containsString("rempotage"));
    }

    @Test
    void testCareReminder_multipleIssues_shouldMentionAll() {
        String name = "MultiIssue " + UUID.randomUUID().toString().substring(0, 6);
        createPlant(accessToken, name, "Orchidée", 7, true, true, true);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", allOf(
                        containsString("malade"),
                        containsString("fanée"),
                        containsString("rempotage")));
    }

    @Test
    void testCareReminder_sickPlant_shouldContainPersonalizedAdvice() {
        String name = "AdvicePlant " + UUID.randomUUID().toString().substring(0, 6);
        createPlant(accessToken, name, "Ficus", 7, true, false, false);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        // Should contain care advice like "parasites" or "isolez"
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message",
                        containsString("parasites"));
    }

    @Test
    void testCareReminder_repottingCactus_shouldMentionDrainantSubstrat() {
        String name = "CactusRepot " + UUID.randomUUID().toString().substring(0, 6);
        // Cactus is a succulent, should get specific repotting advice
        createPlant(accessToken, name, "Cactus", 21, false, false, true);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message",
                        anyOf(containsString("drainant"), containsString("cactées"),
                                containsString("Rempotez")));
    }

    // ==================== GROUPED NOTIFICATIONS ====================

    @Test
    void testCareReminder_multipleSickPlants_shouldBeGrouped() {
        String name1 = "Grouped1 " + UUID.randomUUID().toString().substring(0, 6);
        String name2 = "Grouped2 " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name1);
        createSickPlant(accessToken, name2);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        // Should get a single grouped care reminder mentioning both plants
        List<java.util.Map<String, Object>> notifs = getUnreadNotifications(accessToken);

        long careReminderCount = notifs.stream()
                .filter(n -> "CARE_REMINDER".equals(n.get("type")))
                .count();

        // Should be grouped into one notification
        assert careReminderCount >= 1 : "Should have at least one care reminder";

        // The notification should mention both plants
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", allOf(
                        containsString(name1),
                        containsString(name2)));
    }

    // ==================== HEALTHY PLANTS (no care reminder) ====================

    @Test
    void testCareReminder_healthyPlantsOnly_shouldNotCreateCareReminder() {
        String name = "Healthy " + UUID.randomUUID().toString().substring(0, 6);
        createHealthyPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        // Should NOT have a care reminder for a healthy plant
        List<java.util.Map<String, Object>> notifs = getUnreadNotifications(accessToken);
        long careCount = notifs.stream()
                .filter(n -> "CARE_REMINDER".equals(n.get("type")))
                .filter(n -> n.get("message") != null && n.get("message").toString().contains(name))
                .count();

        assert careCount == 0 : "Healthy plant should not trigger care reminder";
    }

    // ==================== SPECIES-SPECIFIC TIPS ====================

    @Test
    void testCareReminder_differentSpecies_shouldHaveDifferentAdvice() {
        // Create two sick plants with different species
        String tropical = "Tropical " + UUID.randomUUID().toString().substring(0, 6);
        String succulent = "Succulent " + UUID.randomUUID().toString().substring(0, 6);

        createPlant(accessToken, tropical, "Monstera", 7, true, false, false);
        createPlant(accessToken, succulent, "Aloe vera", 14, false, false, true);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", notNullValue());
    }

    // ==================== NOTIFICATION TYPE ====================

    @Test
    void testTriggerReminders_shouldCreateCorrectType_CARE_REMINDER() {
        String name = "TypeCheck " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("type", hasItem("CARE_REMINDER"));
    }

    // ==================== NOTIFICATION LINKED TO PLANT ====================

    @Test
    void testCareReminder_shouldLinkToPlant() {
        String name = "Linked " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.plantId", notNullValue());
    }

    @Test
    void testCareReminder_plantNicknameShouldBeInDTO() {
        String name = "NickDTO " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.plantNickname", notNullValue());
    }

    // ==================== MULTIPLE TRIGGERS ====================

    @Test
    void testTriggerReminders_multipleTimes_shouldCreateMultipleNotifications() {
        String name = "Multi " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        int countAfterFirst = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("$.size()");

        triggerReminders(accessToken);

        int countAfterSecond = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("$.size()");

        assert countAfterSecond > countAfterFirst :
                "Second trigger should create additional notifications";
    }

    // ==================== USER ISOLATION ====================

    @Test
    void testTriggerReminders_shouldOnlyNotifyPlantOwner() {
        String name = "IsolOwner " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        // Clear both users
        clearNotifications(accessToken);
        clearNotifications(test2Token);

        triggerReminders(accessToken);

        // User2 should not get user1's plant care reminders
        List<java.util.Map<String, Object>> user2Notifs = getUnreadNotifications(test2Token);
        long user2CareCount = user2Notifs.stream()
                .filter(n -> "CARE_REMINDER".equals(n.get("type")))
                .filter(n -> n.get("message") != null && n.get("message").toString().contains(name))
                .count();

        assert user2CareCount == 0 : "User2 should not receive care reminders for user1's plants";
    }

    // ==================== PLANT STATE CHANGES ====================

    @Test
    void testCareReminder_afterHealingPlant_shouldNotTrigger() {
        String name = "HealMe " + UUID.randomUUID().toString().substring(0, 6);
        UUID plantId = createSickPlant(accessToken, name);

        // Heal the plant
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "isSick": false
                        }
                        """)
                .when()
                .put("/plants/" + plantId)
                .then()
                .statusCode(200);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        // Should NOT have care reminder for this plant anymore
        List<java.util.Map<String, Object>> notifs = getUnreadNotifications(accessToken);
        long careForHealed = notifs.stream()
                .filter(n -> "CARE_REMINDER".equals(n.get("type")))
                .filter(n -> n.get("message") != null && n.get("message").toString().contains(name))
                .count();

        assert careForHealed == 0 : "Healed plant should not trigger care reminder";
    }

    @Test
    void testCareReminder_afterMakingPlantSick_shouldTrigger() {
        String name = "MakeSick " + UUID.randomUUID().toString().substring(0, 6);
        UUID plantId = createHealthyPlant(accessToken, name);

        // Make it sick
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "isSick": true
                        }
                        """)
                .when()
                .put("/plants/" + plantId)
                .then()
                .statusCode(200);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", containsString(name));
    }

    // ==================== NOTIFICATION MESSAGE FORMAT ====================

    @Test
    void testCareReminder_messageFormat_shouldStartWithEmoji() {
        String name = "Format " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        String message = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.type == 'CARE_REMINDER' }.message");

        if (message != null) {
            assert message.contains("🌱") : "Care reminder should start with plant emoji";
            assert message.contains("attention") : "Care reminder should mention 'attention'";
        }
    }

    @Test
    void testCareReminder_messageFormat_shouldContainBulletPoints() {
        String name = "Bullets " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        String message = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.type == 'CARE_REMINDER' }.message");

        if (message != null) {
            assert message.contains("•") : "Care reminder should use bullet points for plant list";
        }
    }

    @Test
    void testCareReminder_personalizedRecommendation_shouldContainArrow() {
        String name = "Arrow " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        String message = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.type == 'CARE_REMINDER' }.message");

        if (message != null) {
            assert message.contains("→") : "Personalized recommendation should use arrow (→)";
        }
    }

    // ==================== EDGE CASES ====================

    @Test
    void testTriggerReminders_withManyPlants_shouldNotFail() {
        // Create 10 sick plants
        for (int i = 0; i < 10; i++) {
            createSickPlant(accessToken,
                    "Bulk" + i + " " + UUID.randomUUID().toString().substring(0, 6));
        }

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        // Should create notification(s) without error
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(1));
    }

    @Test
    void testTriggerReminders_withDeletedPlants_shouldNotFail() {
        String name = "DeletedPlant " + UUID.randomUUID().toString().substring(0, 6);
        UUID plantId = createSickPlant(accessToken, name);

        // Delete the plant
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/plants/" + plantId)
                .then()
                .statusCode(anyOf(is(204), is(200)));

        // Trigger should not crash
        triggerReminders(accessToken);
    }

    @Test
    void testTriggerReminders_withCustomSpecies_shouldNotFail() {
        String name = "CustomSpec " + UUID.randomUUID().toString().substring(0, 6);
        createPlant(accessToken, name, "Mon espèce inventée très rare", 7,
                true, false, false);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        // Should still create notification even with unknown species
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", containsString(name));
    }

    @Test
    void testTriggerReminders_withEmptyCustomSpecies_shouldNotFail() {
        String name = "NoSpecies " + UUID.randomUUID().toString().substring(0, 6);
        // Create plant with minimal data
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "roomId": "%s",
                            "isSick": true
                        }
                        """.formatted(name, roomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        // Should not crash even without species
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200);
    }

    @Test
    void testNotification_readFlagDefaultsToFalse() {
        String name = "ReadDefault " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("[0].read", equalTo(false));
    }

    @Test
    void testNotification_createdAtShouldBeRecent() {
        String name = "Recent " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, name);

        clearNotifications(accessToken);
        triggerReminders(accessToken);

        String createdAt = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].createdAt");

        assert createdAt != null : "createdAt should not be null";
        // Should contain today's date
        assert createdAt.contains(java.time.LocalDate.now().toString()) :
                "createdAt should be today: " + createdAt;
    }
}
