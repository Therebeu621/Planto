package com.plantmanager.dto;

import java.util.List;
import java.util.Map;

public record DashboardDTO(
        // Overview
        int totalPlants,
        int healthyPlants,
        int sickPlants,
        int needsWateringToday,
        int wateringStreak,
        // Activity feed
        List<ActivityItemDTO> recentActivity,
        // Analytics
        Map<String, Integer> plantsByRoom,
        Map<String, Integer> careActionsThisWeek,
        Map<String, Integer> wateringsLast7Days,
        // Gamification summary
        int xp,
        int level,
        String levelName,
        int badgesUnlocked,
        int totalBadges,
        // House rankings
        List<RankingEntryDTO> houseRankings) {

    public record ActivityItemDTO(
            String type,
            String description,
            String userName,
            String plantName,
            String timeAgo) {
    }

    public record RankingEntryDTO(
            String userName,
            int xp,
            int level,
            String levelName,
            int rank) {
    }
}
