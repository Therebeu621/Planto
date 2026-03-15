package com.plantmanager.dto;

import com.plantmanager.entity.NotificationEntity;
import com.plantmanager.entity.enums.NotificationType;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for notification responses.
 */
public record NotificationDTO(
        UUID id,
        NotificationType type,
        String message,
        boolean read,
        UUID plantId,
        String plantNickname,
        OffsetDateTime createdAt) {

    public static NotificationDTO from(NotificationEntity entity) {
        return new NotificationDTO(
                entity.id,
                entity.type,
                entity.message,
                entity.read != null && entity.read,
                entity.plant != null ? entity.plant.id : null,
                entity.plant != null ? entity.plant.nickname : null,
                entity.createdAt);
    }
}
