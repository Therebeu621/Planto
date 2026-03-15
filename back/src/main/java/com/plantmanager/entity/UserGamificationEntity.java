package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Gamification profile for a user: XP, level, streak.
 */
@Entity
@Table(name = "user_gamification")
public class UserGamificationEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    public UserEntity user;

    @Column(nullable = false)
    public int xp = 0;

    @Column(nullable = false)
    public int level = 1;

    @Column(name = "level_name", nullable = false, length = 50)
    public String levelName = "Graine";

    @Column(name = "watering_streak", nullable = false)
    public int wateringStreak = 0;

    @Column(name = "best_watering_streak", nullable = false)
    public int bestWateringStreak = 0;

    @Column(name = "total_waterings", nullable = false)
    public int totalWaterings = 0;

    @Column(name = "total_care_actions", nullable = false)
    public int totalCareActions = 0;

    @Column(name = "total_plants_added", nullable = false)
    public int totalPlantsAdded = 0;

    @Column(name = "last_watering_date")
    public LocalDate lastWateringDate;

    @Column(name = "updated_at")
    public OffsetDateTime updatedAt;

    // ===== Static finders =====

    public static UserGamificationEntity findByUser(UUID userId) {
        return find("user.id", userId).firstResult();
    }

    /**
     * Get or create gamification profile for a user.
     */
    public static UserGamificationEntity getOrCreate(UUID userId) {
        UserGamificationEntity profile = findByUser(userId);
        if (profile == null) {
            profile = new UserGamificationEntity();
            profile.user = UserEntity.findById(userId);
            profile.persist();
        }
        return profile;
    }

    @PrePersist
    @PreUpdate
    void onUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
