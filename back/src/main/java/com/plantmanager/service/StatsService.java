package com.plantmanager.service;

import com.plantmanager.dto.AnnualStatsDTO;
import com.plantmanager.dto.DashboardDTO;
import com.plantmanager.entity.*;
import com.plantmanager.entity.enums.BadgeType;
import com.plantmanager.entity.enums.CareAction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import java.time.*;
import java.time.format.TextStyle;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@ApplicationScoped
public class StatsService {

    @Inject
    GamificationService gamificationService;

    @Transactional
    public AnnualStatsDTO getAnnualStats(UUID userId, int year) {
        OffsetDateTime startOfYear = LocalDate.of(year, 1, 1).atStartOfDay().atOffset(ZoneOffset.UTC);
        OffsetDateTime endOfYear = LocalDate.of(year, 12, 31).atTime(23, 59, 59).atOffset(ZoneOffset.UTC);

        // All care logs for the year
        List<CareLogEntity> yearLogs = CareLogEntity.list(
                "user.id = ?1 and performedAt >= ?2 and performedAt <= ?3 order by performedAt asc",
                userId, startOfYear, endOfYear);

        int totalWaterings = (int) yearLogs.stream().filter(l -> l.action == CareAction.WATERING).count();
        int totalCareActions = yearLogs.size();

        // Plants added this year
        int plantsAdded = (int) UserPlantEntity.count(
                "user.id = ?1 and createdAt >= ?2 and createdAt <= ?3",
                userId, startOfYear, endOfYear);

        // Best streak
        UserGamificationEntity profile = UserGamificationEntity.getOrCreate(userId);
        int bestStreak = profile.bestWateringStreak;

        // Most cared plant
        Map<String, Long> careByPlant = yearLogs.stream()
                .filter(l -> l.plant != null)
                .collect(Collectors.groupingBy(l -> l.plant.nickname, Collectors.counting()));
        String mostCaredPlant = null;
        int mostCaredCount = 0;
        for (var entry : careByPlant.entrySet()) {
            if (entry.getValue() > mostCaredCount) {
                mostCaredPlant = entry.getKey();
                mostCaredCount = entry.getValue().intValue();
            }
        }

        // Waterings by month
        Map<String, Integer> wateringsByMonth = new LinkedHashMap<>();
        for (int m = 1; m <= 12; m++) {
            String monthName = Month.of(m).getDisplayName(TextStyle.SHORT, Locale.FRENCH);
            int finalM = m;
            long count = yearLogs.stream()
                    .filter(l -> l.action == CareAction.WATERING && l.performedAt.getMonthValue() == finalM)
                    .count();
            wateringsByMonth.put(monthName, (int) count);
        }

        // Care actions by type
        Map<String, Integer> careByType = new LinkedHashMap<>();
        for (CareAction action : CareAction.values()) {
            long count = yearLogs.stream().filter(l -> l.action == action).count();
            if (count > 0) careByType.put(action.name(), (int) count);
        }

        // Monthly activity breakdown
        List<AnnualStatsDTO.MonthlyActivityDTO> monthly = new ArrayList<>();
        for (int m = 1; m <= 12; m++) {
            int finalM = m;
            List<CareLogEntity> monthLogs = yearLogs.stream()
                    .filter(l -> l.performedAt.getMonthValue() == finalM).toList();
            monthly.add(new AnnualStatsDTO.MonthlyActivityDTO(
                    Month.of(m).getDisplayName(TextStyle.SHORT, Locale.FRENCH),
                    (int) monthLogs.stream().filter(l -> l.action == CareAction.WATERING).count(),
                    (int) monthLogs.stream().filter(l -> l.action == CareAction.FERTILIZING).count(),
                    (int) monthLogs.stream().filter(l -> l.action == CareAction.PRUNING).count(),
                    (int) monthLogs.stream().filter(l -> l.action == CareAction.TREATMENT).count(),
                    (int) monthLogs.stream().filter(l -> l.action == CareAction.REPOTTING).count()));
        }

        return new AnnualStatsDTO(
                year, totalWaterings, totalCareActions, plantsAdded, 0,
                bestStreak, mostCaredPlant, mostCaredCount,
                wateringsByMonth, careByType, monthly);
    }

    @Transactional
    public DashboardDTO getDashboard(UUID userId) {
        List<UserPlantEntity> plants = UserPlantEntity.findByUser(userId);
        int totalPlants = plants.size();
        int healthyPlants = (int) plants.stream().filter(p -> !p.isSick && !p.isWilted && !p.needsRepotting).count();
        int sickPlants = (int) plants.stream().filter(p -> p.isSick || p.isWilted).count();
        int needsWateringToday = (int) plants.stream()
                .filter(p -> p.nextWateringDate != null && !p.nextWateringDate.isAfter(LocalDate.now())).count();

        UserGamificationEntity profile = UserGamificationEntity.getOrCreate(userId);

        // Recent activity (last 20)
        List<CareLogEntity> recentLogs = CareLogEntity.find(
                "user.id = ?1 order by performedAt desc", userId).page(0, 20).list();
        List<DashboardDTO.ActivityItemDTO> activity = recentLogs.stream().map(log -> {
            String desc = switch (log.action) {
                case WATERING -> "a arrose";
                case FERTILIZING -> "a fertilise";
                case REPOTTING -> "a rempote";
                case PRUNING -> "a taille";
                case TREATMENT -> "a traite";
                case NOTE -> "a note";
            };
            return new DashboardDTO.ActivityItemDTO(
                    log.action.name(), desc,
                    log.user != null ? log.user.displayName : null,
                    log.plant != null ? log.plant.nickname : null,
                    formatTimeAgo(log.performedAt));
        }).toList();

        // Plants by room
        Map<String, Integer> plantsByRoom = plants.stream()
                .filter(p -> p.room != null)
                .collect(Collectors.groupingBy(p -> p.room.name, Collectors.collectingAndThen(Collectors.counting(), Long::intValue)));

        // Care actions this week
        OffsetDateTime weekAgo = OffsetDateTime.now().minus(7, ChronoUnit.DAYS);
        List<CareLogEntity> weekLogs = CareLogEntity.list(
                "user.id = ?1 and performedAt >= ?2", userId, weekAgo);
        Map<String, Integer> careThisWeek = new LinkedHashMap<>();
        for (CareAction action : CareAction.values()) {
            long count = weekLogs.stream().filter(l -> l.action == action).count();
            if (count > 0) careThisWeek.put(action.name(), (int) count);
        }

        // Waterings last 7 days
        Map<String, Integer> wateringsLast7 = new LinkedHashMap<>();
        for (int i = 6; i >= 0; i--) {
            LocalDate day = LocalDate.now().minusDays(i);
            String dayName = day.getDayOfWeek().getDisplayName(TextStyle.SHORT, Locale.FRENCH);
            int finalI = i;
            long count = weekLogs.stream()
                    .filter(l -> l.action == CareAction.WATERING
                            && l.performedAt.toLocalDate().equals(LocalDate.now().minusDays(finalI)))
                    .count();
            wateringsLast7.put(dayName, (int) count);
        }

        // Badges
        int badgesUnlocked = (int) UserBadgeEntity.count("user.id", userId);
        int totalBadges = BadgeType.values().length;

        // House rankings
        List<DashboardDTO.RankingEntryDTO> rankings = new ArrayList<>();
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership != null) {
            List<UserHouseEntity> members = UserHouseEntity.findByHouse(membership.house.id);
            List<DashboardDTO.RankingEntryDTO> unsorted = new ArrayList<>();
            for (UserHouseEntity m : members) {
                UserGamificationEntity mp = UserGamificationEntity.getOrCreate(m.user.id);
                unsorted.add(new DashboardDTO.RankingEntryDTO(
                        m.user.displayName, mp.xp, mp.level, mp.levelName, 0));
            }
            unsorted.sort((a, b) -> Integer.compare(b.xp(), a.xp()));
            for (int i = 0; i < unsorted.size(); i++) {
                var r = unsorted.get(i);
                rankings.add(new DashboardDTO.RankingEntryDTO(r.userName(), r.xp(), r.level(), r.levelName(), i + 1));
            }
        }

        return new DashboardDTO(
                totalPlants, healthyPlants, sickPlants, needsWateringToday,
                profile.wateringStreak, activity,
                plantsByRoom, careThisWeek, wateringsLast7,
                profile.xp, profile.level, profile.levelName,
                badgesUnlocked, totalBadges, rankings);
    }

    private String formatTimeAgo(OffsetDateTime time) {
        long minutes = ChronoUnit.MINUTES.between(time, OffsetDateTime.now());
        if (minutes < 60) return minutes + " min";
        long hours = minutes / 60;
        if (hours < 24) return hours + "h";
        long days = hours / 24;
        if (days == 1) return "Hier";
        if (days < 7) return days + " jours";
        return (days / 7) + " sem.";
    }
}
