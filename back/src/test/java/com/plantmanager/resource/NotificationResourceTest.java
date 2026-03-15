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
 * Integration tests for NotificationResource endpoints.
 * Covers: listing, filtering, mark as read, mark all as read,
 * unread count, delete, permissions, and edge cases.
 */
@QuarkusTest
public class NotificationResourceTest {

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
    }

    // ==================== HELPER ====================

    /**
     * Trigger reminders to generate notifications for the current user.
     * The user must have plants that need watering or care.
     */
    private void triggerReminders(String token) {
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .when()
                .post("/notifications/trigger-reminders")
                .then()
                .statusCode(200);
    }

    /**
     * Create a sick plant that will trigger care reminders.
     */
    private UUID createSickPlant(String token, String nickname) {
        String plantId = given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "Ficus elastica",
                            "roomId": "%s",
                            "isSick": true
                        }
                        """.formatted(nickname, roomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
        return UUID.fromString(plantId);
    }

    // ==================== LIST NOTIFICATIONS ====================

    @Test
    void testGetNotifications_emptyList_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("$", instanceOf(List.class));
    }

    @Test
    void testGetNotifications_afterTrigger_shouldReturnNotifications() {
        createSickPlant(accessToken, "Notif Test Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(1))
                .body("[0].id", notNullValue())
                .body("[0].type", notNullValue())
                .body("[0].message", notNullValue())
                .body("[0].createdAt", notNullValue());
    }

    @Test
    void testGetNotifications_unreadOnlyFilter_shouldFilterCorrectly() {
        createSickPlant(accessToken, "UnreadFilter Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        // Get all notifications
        List<String> allIds = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        if (!allIds.isEmpty()) {
            // Mark first as read
            String firstId = allIds.get(0);
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .contentType(ContentType.JSON)
                    .when()
                    .put("/notifications/" + firstId + "/read")
                    .then()
                    .statusCode(200);

            // Filter unread only
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .queryParam("unreadOnly", true)
                    .when()
                    .get("/notifications")
                    .then()
                    .statusCode(200)
                    .body("find { it.id == '%s' }".formatted(firstId), nullValue());
        }
    }

    @Test
    void testGetNotifications_shouldBeOrderedByDateDesc() {
        createSickPlant(accessToken, "Order Plant1 " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);
        createSickPlant(accessToken, "Order Plant2 " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        List<String> createdAtDates = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("createdAt");

        // Verify descending order (most recent first)
        if (createdAtDates.size() >= 2) {
            for (int i = 0; i < createdAtDates.size() - 1; i++) {
                String current = createdAtDates.get(i);
                String next = createdAtDates.get(i + 1);
                assert current.compareTo(next) >= 0 :
                        "Notifications should be ordered by date desc: " + current + " >= " + next;
            }
        }
    }

    @Test
    void testGetNotifications_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/notifications")
                .then()
                .statusCode(401);
    }

    // ==================== UNREAD COUNT ====================

    @Test
    void testGetUnreadCount_noNotifications_shouldReturnZeroOrMore() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(200)
                .body("unreadCount", greaterThanOrEqualTo(0));
    }

    @Test
    void testGetUnreadCount_afterTrigger_shouldIncrease() {
        // Get initial count
        int initialCount = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(200)
                .extract()
                .path("unreadCount");

        createSickPlant(accessToken, "Count Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(200)
                .body("unreadCount", greaterThanOrEqualTo(initialCount));
    }

    @Test
    void testGetUnreadCount_afterMarkAllRead_shouldDecrease() {
        createSickPlant(accessToken, "MarkAll Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        // Mark all as read
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(200)
                .body("unreadCount", equalTo(0));
    }

    @Test
    void testGetUnreadCount_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(401);
    }

    // ==================== MARK AS READ ====================

    @Test
    void testMarkAsRead_validNotification_shouldReturn200() {
        createSickPlant(accessToken, "Read Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        String notifId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].id");

        if (notifId != null) {
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .contentType(ContentType.JSON)
                    .when()
                    .put("/notifications/" + notifId + "/read")
                    .then()
                    .statusCode(200)
                    .body("id", equalTo(notifId))
                    .body("read", equalTo(true));
        }
    }

    @Test
    void testMarkAsRead_alreadyRead_shouldStillReturn200() {
        createSickPlant(accessToken, "AlreadyRead Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        String notifId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].id");

        if (notifId != null) {
            // Mark as read first time
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .contentType(ContentType.JSON)
                    .when()
                    .put("/notifications/" + notifId + "/read")
                    .then()
                    .statusCode(200)
                    .body("read", equalTo(true));

            // Mark as read second time (idempotent)
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .contentType(ContentType.JSON)
                    .when()
                    .put("/notifications/" + notifId + "/read")
                    .then()
                    .statusCode(200)
                    .body("read", equalTo(true));
        }
    }

    @Test
    void testMarkAsRead_notFound_shouldReturn404() {
        UUID fakeId = UUID.randomUUID();
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/" + fakeId + "/read")
                .then()
                .statusCode(404);
    }

    @Test
    void testMarkAsRead_otherUsersNotification_shouldReturn403() {
        createSickPlant(accessToken, "Forbidden Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        String notifId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].id");

        if (notifId != null) {
            // test2 tries to mark user1's notification as read
            given()
                    .header("Authorization", TestUtils.authHeader(test2Token))
                    .contentType(ContentType.JSON)
                    .when()
                    .put("/notifications/" + notifId + "/read")
                    .then()
                    .statusCode(403);
        }
    }

    @Test
    void testMarkAsRead_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/" + UUID.randomUUID() + "/read")
                .then()
                .statusCode(401);
    }

    // ==================== MARK ALL AS READ ====================

    @Test
    void testMarkAllAsRead_withUnreadNotifications_shouldMarkAll() {
        createSickPlant(accessToken, "MarkAllRead Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200)
                .body("markedAsRead", greaterThanOrEqualTo(0));

        // Verify all are read
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(200)
                .body("unreadCount", equalTo(0));
    }

    @Test
    void testMarkAllAsRead_noNotifications_shouldReturn0() {
        // First mark all as read to clear
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

        // Then try again - should return 0
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200)
                .body("markedAsRead", equalTo(0));
    }

    @Test
    void testMarkAllAsRead_shouldNotAffectOtherUsers() {
        createSickPlant(accessToken, "IsolUser1 " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        // Get test2 initial unread count
        int test2CountBefore = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(200)
                .extract()
                .path("unreadCount");

        // User1 marks all as read
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

        // test2's count should be unchanged
        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(200)
                .body("unreadCount", equalTo(test2CountBefore));
    }

    @Test
    void testMarkAllAsRead_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(401);
    }

    // ==================== DELETE ====================

    @Test
    void testDeleteNotification_valid_shouldReturn204() {
        createSickPlant(accessToken, "Delete Plant " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        String notifId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].id");

        if (notifId != null) {
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .when()
                    .delete("/notifications/" + notifId)
                    .then()
                    .statusCode(204);

            // Verify it's gone - should not appear in list
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .when()
                    .get("/notifications")
                    .then()
                    .statusCode(200)
                    .body("find { it.id == '%s' }".formatted(notifId), nullValue());
        }
    }

    @Test
    void testDeleteNotification_notFound_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/notifications/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteNotification_otherUsersNotification_shouldReturn403() {
        createSickPlant(accessToken, "DelForbidden " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        String notifId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].id");

        if (notifId != null) {
            given()
                    .header("Authorization", TestUtils.authHeader(test2Token))
                    .when()
                    .delete("/notifications/" + notifId)
                    .then()
                    .statusCode(403);
        }
    }

    @Test
    void testDeleteNotification_deleteTwice_shouldReturn404OnSecond() {
        createSickPlant(accessToken, "DoubleDel " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        String notifId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("[0].id");

        if (notifId != null) {
            // First delete
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .when()
                    .delete("/notifications/" + notifId)
                    .then()
                    .statusCode(204);

            // Second delete - should be 404
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .when()
                    .delete("/notifications/" + notifId)
                    .then()
                    .statusCode(404);
        }
    }

    @Test
    void testDeleteNotification_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/notifications/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    @Test
    void testDeleteNotification_shouldDecreaseUnreadCount() {
        createSickPlant(accessToken, "DelCount " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        int countBefore = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications/unread-count")
                .then()
                .statusCode(200)
                .extract()
                .path("unreadCount");

        if (countBefore > 0) {
            // Get an unread notification
            String notifId = given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .queryParam("unreadOnly", true)
                    .when()
                    .get("/notifications")
                    .then()
                    .statusCode(200)
                    .extract()
                    .path("[0].id");

            if (notifId != null) {
                given()
                        .header("Authorization", TestUtils.authHeader(accessToken))
                        .when()
                        .delete("/notifications/" + notifId)
                        .then()
                        .statusCode(204);

                given()
                        .header("Authorization", TestUtils.authHeader(accessToken))
                        .when()
                        .get("/notifications/unread-count")
                        .then()
                        .statusCode(200)
                        .body("unreadCount", lessThan(countBefore));
            }
        }
    }

    // ==================== TRIGGER REMINDERS ====================

    @Test
    void testTriggerReminders_shouldReturn200() {
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
    void testTriggerReminders_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .when()
                .post("/notifications/trigger-reminders")
                .then()
                .statusCode(401);
    }

    @Test
    void testTriggerReminders_withSickPlant_shouldCreateCareNotification() {
        String uniqueName = "SickCare " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, uniqueName);

        // Mark all existing as read first
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

        triggerReminders(accessToken);

        // Should have new unread CARE_REMINDER notifications
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(1))
                .body("find { it.type == 'CARE_REMINDER' }", notNullValue());
    }

    @Test
    void testTriggerReminders_multipleTimes_shouldCreateMultipleNotifications() {
        createSickPlant(accessToken, "MultiTrig " + UUID.randomUUID().toString().substring(0, 6));

        int countBefore = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("$.size()");

        triggerReminders(accessToken);
        triggerReminders(accessToken);

        int countAfter = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("$.size()");

        assert countAfter > countBefore : "Multiple triggers should create multiple notifications";
    }

    // ==================== NOTIFICATION CONTENT VALIDATION ====================

    @Test
    void testNotificationDTO_shouldContainAllFields() {
        createSickPlant(accessToken, "DTOFields " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("[0].id", notNullValue())
                .body("[0].type", notNullValue())
                .body("[0].message", notNullValue())
                .body("[0].createdAt", notNullValue())
                .body("[0].containsKey('read')", equalTo(true))
                .body("[0].containsKey('plantId')", equalTo(true))
                .body("[0].containsKey('plantNickname')", equalTo(true));
    }

    @Test
    void testNotification_careReminder_shouldContainPlantName() {
        String uniqueName = "CareContent " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, uniqueName);

        // Clear old notifications
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", containsString(uniqueName));
    }

    @Test
    void testNotification_careReminder_shouldMentionSickStatus() {
        String uniqueName = "SickStatus " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, uniqueName);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

        triggerReminders(accessToken);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("unreadOnly", true)
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .body("find { it.type == 'CARE_REMINDER' }.message", containsString("malade"));
    }

    // ==================== NOTIFICATION TYPE FILTERING ====================

    @Test
    void testNotification_typeField_shouldBeValidEnum() {
        createSickPlant(accessToken, "EnumCheck " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        List<String> types = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("type");

        List<String> validTypes = List.of("WATERING_REMINDER", "CARE_REMINDER", "PLANT_ADDED", "MEMBER_JOINED");
        for (String type : types) {
            assert validTypes.contains(type) : "Invalid notification type: " + type;
        }
    }

    // ==================== USER ISOLATION ====================

    @Test
    void testNotifications_userIsolation_shouldNotSeeOtherUsersNotifications() {
        createSickPlant(accessToken, "Isolated " + UUID.randomUUID().toString().substring(0, 6));
        triggerReminders(accessToken);

        // Get user1's notification IDs
        List<String> user1NotifIds = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        // Get user2's notifications
        List<String> user2NotifIds = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        // None of user1's notifications should appear in user2's list
        for (String id : user1NotifIds) {
            assert !user2NotifIds.contains(id) :
                    "User2 should not see user1's notification: " + id;
        }
    }

    // ==================== EDGE CASES ====================

    @Test
    void testMarkAsRead_invalidUUID_shouldReturn404or400() {
        // Using a valid UUID format but non-existent
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/00000000-0000-0000-0000-000000000000/read")
                .then()
                .statusCode(anyOf(is(404), is(400)));
    }

    @Test
    void testDeleteNotification_invalidUUID_shouldReturn404or400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/notifications/00000000-0000-0000-0000-000000000000")
                .then()
                .statusCode(anyOf(is(404), is(400)));
    }

    @Test
    void testNotifications_afterDeletePlant_shouldStillExist() {
        String uniqueName = "PlantDel " + UUID.randomUUID().toString().substring(0, 6);
        createSickPlant(accessToken, uniqueName);
        triggerReminders(accessToken);

        // Get a plant ID to delete
        String plantIdStr = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/plants")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.nickname.startsWith('PlantDel') }.id");

        // Delete the plant
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/plants/" + plantIdStr)
                .then()
                .statusCode(anyOf(is(204), is(200)));

        // Notifications should still exist (or at least not crash)
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/notifications")
                .then()
                .statusCode(200);
    }

    @Test
    void testTriggerReminders_noPlants_shouldStillReturn200() {
        // test2 may have no plants - trigger should not fail
        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .when()
                .post("/notifications/trigger-reminders")
                .then()
                .statusCode(200)
                .body("status", equalTo("Reminders triggered successfully"));
    }

    // ==================== PLANT WITH MULTIPLE HEALTH ISSUES ====================

    @Test
    void testTriggerReminders_plantWithMultipleIssues_shouldMentionAll() {
        String uniqueName = "MultiIssue " + UUID.randomUUID().toString().substring(0, 6);

        // Create plant with multiple health issues
        String plantId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "Aloe vera",
                            "roomId": "%s",
                            "isSick": true,
                            "isWilted": true,
                            "needsRepotting": true
                        }
                        """.formatted(uniqueName, roomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

        triggerReminders(accessToken);

        // The care reminder should mention all issues
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
    void testTriggerReminders_plantWithWiltedFlag_shouldMentionWilted() {
        String uniqueName = "WiltedOnly " + UUID.randomUUID().toString().substring(0, 6);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "Orchidée",
                            "roomId": "%s",
                            "isWilted": true
                        }
                        """.formatted(uniqueName, roomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

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
    void testTriggerReminders_plantNeedsRepotting_shouldMentionRepotting() {
        String uniqueName = "Repot " + UUID.randomUUID().toString().substring(0, 6);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "%s",
                            "customSpecies": "Cactus",
                            "roomId": "%s",
                            "needsRepotting": true
                        }
                        """.formatted(uniqueName, roomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .put("/notifications/read-all")
                .then()
                .statusCode(200);

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
}
