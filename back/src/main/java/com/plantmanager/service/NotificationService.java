package com.plantmanager.service;

import com.plantmanager.dto.NotificationDTO;
import com.plantmanager.entity.NotificationEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.entity.enums.NotificationType;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.ForbiddenException;
import org.jboss.logging.Logger;

import java.util.List;
import java.util.UUID;

/**
 * Service for notification management.
 */
@ApplicationScoped
public class NotificationService {

    private static final Logger LOG = Logger.getLogger(NotificationService.class);

    /**
     * Get all notifications for a user (most recent first).
     */
    public List<NotificationDTO> getNotificationsByUser(UUID userId) {
        List<NotificationEntity> notifications = NotificationEntity.findByUser(userId);
        return notifications.stream()
                .map(NotificationDTO::from)
                .toList();
    }

    /**
     * Get unread notifications for a user.
     */
    public List<NotificationDTO> getUnreadNotifications(UUID userId) {
        List<NotificationEntity> notifications = NotificationEntity.findUnreadByUser(userId);
        return notifications.stream()
                .map(NotificationDTO::from)
                .toList();
    }

    /**
     * Count unread notifications for a user.
     */
    public long countUnread(UUID userId) {
        return NotificationEntity.countUnreadByUser(userId);
    }

    /**
     * Mark a single notification as read.
     */
    @Transactional
    public NotificationDTO markAsRead(UUID userId, UUID notificationId) {
        NotificationEntity notification = NotificationEntity.findById(notificationId);
        if (notification == null) {
            throw new NotFoundException("Notification not found");
        }
        if (!notification.user.id.equals(userId)) {
            throw new ForbiddenException("Not your notification");
        }
        notification.read = true;
        return NotificationDTO.from(notification);
    }

    /**
     * Mark all notifications as read for a user.
     */
    @Transactional
    public int markAllAsRead(UUID userId) {
        int count = NotificationEntity.markAllAsReadByUser(userId);
        LOG.infof("Marked %d notifications as read for user %s", count, userId);
        return count;
    }

    /**
     * Delete a notification.
     */
    @Transactional
    public void deleteNotification(UUID userId, UUID notificationId) {
        NotificationEntity notification = NotificationEntity.findById(notificationId);
        if (notification == null) {
            throw new NotFoundException("Notification not found");
        }
        if (!notification.user.id.equals(userId)) {
            throw new ForbiddenException("Not your notification");
        }
        notification.delete();
    }

    /**
     * Create an in-app notification for a user.
     */
    @Transactional
    public NotificationEntity createNotification(UUID userId, UUID plantId, NotificationType type, String message) {
        UserEntity user = UserEntity.findById(userId);
        if (user == null) return null;

        NotificationEntity notification = new NotificationEntity();
        notification.user = user;
        notification.type = type;
        notification.message = message;

        if (plantId != null) {
            UserPlantEntity plant = UserPlantEntity.findById(plantId);
            notification.plant = plant;
        }

        notification.persist();
        return notification;
    }
}
