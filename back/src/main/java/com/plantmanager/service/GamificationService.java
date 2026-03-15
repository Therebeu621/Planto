package com.plantmanager.service;

import com.plantmanager.dto.BadgeDTO;
import com.plantmanager.dto.GamificationProfileDTO;
import com.plantmanager.entity.*;
import com.plantmanager.entity.enums.BadgeType;
import com.plantmanager.entity.enums.CareAction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.jboss.logging.Logger;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Service for gamification: XP, levels, badges, streaks.
 *
 * XP rules:
 * - Watering (when needed): 10 XP
 * - Care action (fertilize, repot, prune, treat): 15 XP (max 1 per type per plant per day)
 * - Add a plant: 20 XP
 * - Streak bonus (7 days on time): 50 XP
 * - Streak bonus (30 days): 200 XP
 *
 * No XP for: photos, notes, redundant waterings
 */
@ApplicationScoped
public class GamificationService {

    private static final Logger LOG = Logger.getLogger(GamificationService.class);

    // Level thresholds: level -> min XP
    private static final int[][] LEVELS = {
            {1, 0, },       // Graine
            {2, 100},       // Pousse
            {3, 300},       // Bourgeon
            {4, 600},       // Feuille
            {5, 1000},      // Fleur
            {6, 2000},      // Arbre
            {7, 5000},      // Jardinier Expert
    };

    private static final String[] LEVEL_NAMES = {
            "Graine", "Pousse", "Bourgeon", "Feuille", "Fleur", "Arbre", "Jardinier Expert"
    };

    @Inject
    FcmService fcmService;

    // ===== XP Award Methods =====

    /**
     * Award XP for watering a plant (only if it needed watering).
     */
    @Transactional
    public void onPlantWatered(UUID userId, UserPlantEntity plant) {
        UserGamificationEntity profile = UserGamificationEntity.getOrCreate(userId);

        // Award watering XP
        addXp(profile, 10);
        profile.totalWaterings++;

        // Update streak
        LocalDate today = LocalDate.now();
        if (profile.lastWateringDate == null || profile.lastWateringDate.isBefore(today)) {
            if (profile.lastWateringDate != null && profile.lastWateringDate.equals(today.minusDays(1))) {
                // Consecutive day -> increment streak
                profile.wateringStreak++;
            } else if (profile.lastWateringDate == null || !profile.lastWateringDate.equals(today)) {
                // Gap or first time -> reset streak to 1
                profile.wateringStreak = 1;
            }
            profile.lastWateringDate = today;

            if (profile.wateringStreak > profile.bestWateringStreak) {
                profile.bestWateringStreak = profile.wateringStreak;
            }

            // Streak bonuses
            if (profile.wateringStreak == 7) {
                addXp(profile, 50);
                LOG.infof("User %s earned 50 XP streak bonus (7 days)", userId);
            }
            if (profile.wateringStreak == 30) {
                addXp(profile, 200);
                LOG.infof("User %s earned 200 XP streak bonus (30 days)", userId);
            }
        }

        updateLevel(profile);
        checkBadges(userId, profile);
    }

    /**
     * Award XP for a care action (max 1 per type per plant per day).
     */
    @Transactional
    public void onCareAction(UUID userId, UUID plantId, CareAction action) {
        // Notes don't give XP
        if (action == CareAction.NOTE || action == CareAction.WATERING) {
            return;
        }

        // Check if user already did this action on this plant today
        LocalDate today = LocalDate.now();
        long todayCount = CareLogEntity.count(
                "user.id = ?1 and plant.id = ?2 and action = ?3 and cast(performedAt as LocalDate) = ?4",
                userId, plantId, action, today);
        if (todayCount > 1) {
            // Already earned XP for this action on this plant today
            return;
        }

        UserGamificationEntity profile = UserGamificationEntity.getOrCreate(userId);
        addXp(profile, 15);
        profile.totalCareActions++;
        updateLevel(profile);
        checkBadges(userId, profile);
    }

    /**
     * Award XP for adding a new plant.
     */
    @Transactional
    public void onPlantAdded(UUID userId) {
        UserGamificationEntity profile = UserGamificationEntity.getOrCreate(userId);
        addXp(profile, 20);
        profile.totalPlantsAdded++;
        updateLevel(profile);
        checkBadges(userId, profile);
    }

    /**
     * Check badges when joining a house.
     */
    @Transactional
    public void onHouseJoined(UUID userId, UUID houseId) {
        UserGamificationEntity.getOrCreate(userId);
        long memberCount = UserHouseEntity.countByHouse(houseId);
        if (memberCount >= 2) {
            unlockBadge(userId, BadgeType.TEAM_PLAYER);
        }
    }

    /**
     * Check badges when accepting a vacation delegation.
     */
    @Transactional
    public void onDelegationAccepted(UUID delegateId) {
        unlockBadge(delegateId, BadgeType.GUARDIAN_ANGEL);
    }

    // ===== Profile & Badges Query =====

    /**
     * Get gamification profile with all badges.
     */
    @Transactional
    public GamificationProfileDTO getProfile(UUID userId) {
        UserGamificationEntity profile = UserGamificationEntity.getOrCreate(userId);

        // Get unlocked badges
        List<UserBadgeEntity> unlockedBadges = UserBadgeEntity.findByUser(userId);
        Set<BadgeType> unlockedTypes = unlockedBadges.stream()
                .map(b -> b.badge)
                .collect(Collectors.toSet());

        // Build full badge list (unlocked + locked)
        List<BadgeDTO> allBadges = new ArrayList<>();
        for (BadgeType type : BadgeType.values()) {
            if (unlockedTypes.contains(type)) {
                UserBadgeEntity entity = unlockedBadges.stream()
                        .filter(b -> b.badge == type).findFirst().orElse(null);
                allBadges.add(BadgeDTO.fromUnlocked(entity));
            } else {
                allBadges.add(BadgeDTO.fromLocked(type));
            }
        }

        // Calculate XP progress
        int[] progress = getXpProgress(profile.xp);

        return GamificationProfileDTO.from(profile, allBadges, progress[0], progress[1]);
    }

    /**
     * Get leaderboard for a house.
     */
    @Transactional
    public List<GamificationProfileDTO> getHouseLeaderboard(UUID userId, UUID houseId) {
        // Verify membership
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new jakarta.ws.rs.ForbiddenException("You are not a member of this house");
        }

        List<UserHouseEntity> members = UserHouseEntity.findByHouse(houseId);

        return members.stream()
                .map(m -> getProfile(m.user.id))
                .sorted((a, b) -> Integer.compare(b.xp(), a.xp()))
                .toList();
    }

    // ===== Internal helpers =====

    private void addXp(UserGamificationEntity profile, int amount) {
        profile.xp += amount;
        LOG.infof("Added %d XP to user %s (total: %d)", amount, profile.user.id, profile.xp);
    }

    private void updateLevel(UserGamificationEntity profile) {
        for (int i = LEVELS.length - 1; i >= 0; i--) {
            if (profile.xp >= LEVELS[i][1]) {
                int newLevel = LEVELS[i][0];
                if (newLevel > profile.level) {
                    profile.level = newLevel;
                    profile.levelName = LEVEL_NAMES[i];
                    LOG.infof("User %s leveled up to %d (%s)!", profile.user.id, newLevel, LEVEL_NAMES[i]);

                    // Notify user
                    fcmService.sendToUser(profile.user.id,
                            "Niveau superieur !",
                            "Vous etes maintenant " + LEVEL_NAMES[i] + " (niveau " + newLevel + ")",
                            Map.of("type", "LEVEL_UP", "level", String.valueOf(newLevel)));
                }
                break;
            }
        }
    }

    private int[] getXpProgress(int xp) {
        int currentLevelXp = 0;
        int nextLevelXp = LEVELS[LEVELS.length - 1][1]; // Max level XP

        for (int i = 0; i < LEVELS.length - 1; i++) {
            if (xp >= LEVELS[i][1] && xp < LEVELS[i + 1][1]) {
                currentLevelXp = LEVELS[i][1];
                nextLevelXp = LEVELS[i + 1][1];
                break;
            }
        }

        int xpForNextLevel = nextLevelXp - currentLevelXp;
        int xpProgressInLevel = xp - currentLevelXp;

        return new int[]{xpForNextLevel, xpProgressInLevel};
    }

    private void checkBadges(UUID userId, UserGamificationEntity profile) {
        // FIRST_WATERING: 1+ waterings
        if (profile.totalWaterings >= 1) {
            unlockBadge(userId, BadgeType.FIRST_WATERING);
        }

        // GREEN_THUMB: 50 waterings
        if (profile.totalWaterings >= 50) {
            unlockBadge(userId, BadgeType.GREEN_THUMB);
        }

        // CARETAKER: 10 care actions
        if (profile.totalCareActions >= 10) {
            unlockBadge(userId, BadgeType.CARETAKER);
        }

        // PUNCTUAL: 7-day streak
        if (profile.bestWateringStreak >= 7) {
            unlockBadge(userId, BadgeType.PUNCTUAL);
        }

        // MARATHON: 30-day streak
        if (profile.bestWateringStreak >= 30) {
            unlockBadge(userId, BadgeType.MARATHON);
        }

        // Collection badges - count user's plants
        long plantCount = UserPlantEntity.count("user.id", userId);
        if (plantCount >= 5) {
            unlockBadge(userId, BadgeType.COLLECTOR);
        }
        if (plantCount >= 15) {
            unlockBadge(userId, BadgeType.URBAN_JUNGLE);
        }

        // BOTANIST: 5 different species (by species or customSpecies)
        Long speciesFromDb = UserPlantEntity.getEntityManager()
                .createQuery("SELECT COUNT(DISTINCT p.species.id) FROM UserPlantEntity p WHERE p.user.id = ?1 AND p.species IS NOT NULL", Long.class)
                .setParameter(1, userId)
                .getSingleResult();
        Long customSpeciesCount = UserPlantEntity.getEntityManager()
                .createQuery("SELECT COUNT(DISTINCT p.customSpecies) FROM UserPlantEntity p WHERE p.user.id = ?1 AND p.customSpecies IS NOT NULL", Long.class)
                .setParameter(1, userId)
                .getSingleResult();
        long totalSpecies = (speciesFromDb != null ? speciesFromDb : 0) + (customSpeciesCount != null ? customSpeciesCount : 0);
        if (totalSpecies >= 5) {
            unlockBadge(userId, BadgeType.BOTANIST);
        }
    }

    private void unlockBadge(UUID userId, BadgeType badge) {
        if (UserBadgeEntity.hasBadge(userId, badge)) {
            return;
        }

        UserBadgeEntity entity = new UserBadgeEntity();
        entity.user = UserEntity.findById(userId);
        entity.badge = badge;
        entity.persist();

        LOG.infof("Badge unlocked for user %s: %s", userId, badge.getDisplayName());

        // Notify user
        fcmService.sendToUser(userId,
                "Badge debloque !",
                badge.getDisplayName() + " - " + badge.getDescription(),
                Map.of("type", "BADGE_UNLOCKED", "badge", badge.name()));
    }
}
