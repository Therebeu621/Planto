package com.plantmanager.dto;

import java.util.List;
import java.util.Map;

public record AnnualStatsDTO(
        int year,
        int totalWaterings,
        int totalCareActions,
        int plantsAdded,
        int plantsLost,
        int bestStreak,
        String mostCaredPlant,
        int mostCaredPlantActions,
        Map<String, Integer> wateringsByMonth,
        Map<String, Integer> careActionsByType,
        List<MonthlyActivityDTO> monthlyActivity) {

    public record MonthlyActivityDTO(
            String month,
            int waterings,
            int fertilizations,
            int prunings,
            int treatments,
            int repottings) {
    }
}
