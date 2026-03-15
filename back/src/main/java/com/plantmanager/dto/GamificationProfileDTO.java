package com.plantmanager.dto;

import com.plantmanager.entity.UserGamificationEntity;

import java.util.List;

/**
 * DTO for user gamification profile.
 */
public record GamificationProfileDTO(
        int xp,
        int level,
        String levelName,
        int xpForNextLevel,
        int xpProgressInLevel,
        int wateringStreak,
        int bestWateringStreak,
        int totalWaterings,
        int totalCareActions,
        int totalPlantsAdded,
        List<BadgeDTO> badges) {

    public static GamificationProfileDTO from(UserGamificationEntity entity, List<BadgeDTO> badges,
                                               int xpForNextLevel, int xpProgressInLevel) {
        return new GamificationProfileDTO(
                entity.xp,
                entity.level,
                entity.levelName,
                xpForNextLevel,
                xpProgressInLevel,
                entity.wateringStreak,
                entity.bestWateringStreak,
                entity.totalWaterings,
                entity.totalCareActions,
                entity.totalPlantsAdded,
                badges);
    }
}
