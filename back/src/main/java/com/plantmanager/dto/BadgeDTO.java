package com.plantmanager.dto;

import com.plantmanager.entity.UserBadgeEntity;
import com.plantmanager.entity.enums.BadgeType;

import java.time.OffsetDateTime;

/**
 * DTO for a badge (unlocked or locked).
 */
public record BadgeDTO(
        String code,
        String name,
        String description,
        String category,
        String iconUrl,
        boolean unlocked,
        OffsetDateTime unlockedAt) {

    public static BadgeDTO fromUnlocked(UserBadgeEntity entity) {
        return new BadgeDTO(
                entity.badge.name(),
                entity.badge.getDisplayName(),
                entity.badge.getDescription(),
                entity.badge.getCategory(),
                entity.badge.getIconUrl(),
                true,
                entity.unlockedAt);
    }

    public static BadgeDTO fromLocked(BadgeType badge) {
        return new BadgeDTO(
                badge.name(),
                badge.getDisplayName(),
                badge.getDescription(),
                badge.getCategory(),
                badge.getIconUrl(),
                false,
                null);
    }
}
