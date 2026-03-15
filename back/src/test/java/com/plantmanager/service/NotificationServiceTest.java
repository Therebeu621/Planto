package com.plantmanager.service;

import com.plantmanager.TestUtils;
import com.plantmanager.dto.NotificationDTO;
import com.plantmanager.entity.NotificationEntity;
import com.plantmanager.entity.enums.NotificationType;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit / integration tests for NotificationService edge cases.
 * The resource-level tests cover the main flows; these tests target
 * branches not reachable via the REST API.
 */
@QuarkusTest
public class NotificationServiceTest {

    @Inject
    NotificationService notificationService;

    private String accessToken;
    private UUID userId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        String userIdStr = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/auth/me")
                .then()
                .statusCode(200)
                .extract()
                .path("id");
        userId = UUID.fromString(userIdStr);
    }

    // ==================== createNotification ====================

    @Test
    void testCreateNotification_nullUser_shouldReturnNull() {
        UUID nonExistentUserId = UUID.randomUUID();
        NotificationEntity result = notificationService.createNotification(
                nonExistentUserId,
                null,
                NotificationType.CARE_REMINDER,
                "Test message"
        );
        assertNull(result, "Should return null when user does not exist");
    }

    @Test
    void testCreateNotification_withNullPlantId_shouldCreateNotification() {
        NotificationEntity result = notificationService.createNotification(
                userId,
                null,
                NotificationType.CARE_REMINDER,
                "Test care reminder without plant"
        );
        assertNotNull(result, "Should create notification when user exists");
        assertNotNull(result.id);
        assertEquals(NotificationType.CARE_REMINDER, result.type);
        assertEquals("Test care reminder without plant", result.message);
        assertNull(result.plant, "Plant should be null when plantId is null");
    }

    @Test
    void testCreateNotification_withNonExistentPlantId_shouldCreateNotificationWithNullPlant() {
        UUID fakePlantId = UUID.randomUUID();
        NotificationEntity result = notificationService.createNotification(
                userId,
                fakePlantId,
                NotificationType.WATERING_REMINDER,
                "Test watering reminder"
        );
        assertNotNull(result, "Should create notification even with non-existent plant");
        assertNull(result.plant, "Plant should be null when plant doesn't exist");
    }

    // ==================== getNotificationsByUser ====================

    @Test
    void testGetNotificationsByUser_shouldReturnList() {
        List<NotificationDTO> notifications = notificationService.getNotificationsByUser(userId);
        assertNotNull(notifications);
    }

    @Test
    void testGetNotificationsByUser_unknownUser_shouldReturnEmptyList() {
        List<NotificationDTO> notifications = notificationService.getNotificationsByUser(UUID.randomUUID());
        assertNotNull(notifications);
        assertTrue(notifications.isEmpty());
    }

    // ==================== getUnreadNotifications ====================

    @Test
    void testGetUnreadNotifications_shouldReturnList() {
        List<NotificationDTO> unread = notificationService.getUnreadNotifications(userId);
        assertNotNull(unread);
    }

    // ==================== countUnread ====================

    @Test
    void testCountUnread_shouldReturnNonNegative() {
        long count = notificationService.countUnread(userId);
        assertTrue(count >= 0);
    }

    // ==================== markAllAsRead ====================

    @Test
    void testMarkAllAsRead_shouldReturnCount() {
        // Create a notification first
        notificationService.createNotification(
                userId,
                null,
                NotificationType.CARE_REMINDER,
                "Mark all test"
        );

        int marked = notificationService.markAllAsRead(userId);
        assertTrue(marked >= 0, "markAllAsRead should return non-negative count");

        // After marking all, unread count should be 0
        assertEquals(0, notificationService.countUnread(userId));
    }
}
