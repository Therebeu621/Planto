package com.plantmanager.entity;

import com.plantmanager.entity.enums.Exposure;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * User plant entity representing a plant owned by a user.
 * Maps to the 'user_plant' table.
 */
@Entity
@Table(name = "user_plant")
public class UserPlantEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    public UserEntity user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "room_id")
    public RoomEntity room;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "species_id")
    public SpeciesCacheEntity species;

    @Column(length = 100)
    public String nickname;

    @Column(name = "photo_path", columnDefinition = "TEXT")
    public String photoPath;

    @Column(name = "acquired_at")
    public LocalDate acquiredAt;

    @Column(name = "last_watered")
    public OffsetDateTime lastWatered;

    @Column(name = "watering_interval_days")
    public Integer wateringIntervalDays = 7;

    @Column(columnDefinition = "TEXT")
    public String notes;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    // New fields for health and exposure tracking
    @Column(name = "is_sick")
    public boolean isSick = false;

    @Column(name = "is_wilted")
    public boolean isWilted = false;

    @Column(name = "needs_repotting")
    public boolean needsRepotting = false;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(columnDefinition = "exposure")
    public Exposure exposure = Exposure.PARTIAL_SHADE;

    // Pre-calculated next watering date for fast queries
    @Column(name = "next_watering_date")
    public LocalDate nextWateringDate;

    // Pot diameter in cm (for pot stock management)
    @Column(name = "pot_diameter_cm", precision = 5, scale = 1)
    public BigDecimal potDiameterCm;

    // Custom species name when user types a species not in the database
    @Column(name = "custom_species", length = 200)
    public String customSpecies;

    // One-to-Many: Plant has many CareLogs
    @OneToMany(mappedBy = "plant", fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
    public List<CareLogEntity> careLogs = new ArrayList<>();

    // One-to-Many: Plant has many Notifications
    @OneToMany(mappedBy = "plant", fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
    public List<NotificationEntity> notifications = new ArrayList<>();

    // ===== Static finder methods =====

    public static List<UserPlantEntity> findByUser(UUID userId) {
        return list("user.id", userId);
    }

    public static List<UserPlantEntity> findByUserAndRoom(UUID userId, UUID roomId) {
        return list("user.id = ?1 and room.id = ?2", userId, roomId);
    }

    public static List<UserPlantEntity> findByRoom(UUID roomId) {
        return list("room.id", roomId);
    }

    public static List<UserPlantEntity> searchByNickname(UUID userId, String query) {
        return list("user.id = ?1 and lower(nickname) like ?2", userId, "%" + query.toLowerCase() + "%");
    }

    public static List<UserPlantEntity> findNeedingWater(UUID userId) {
        return list("user.id = ?1 and nextWateringDate <= ?2", userId, LocalDate.now());
    }

    public static List<UserPlantEntity> findNeedingWaterByHouse(UUID houseId) {
        return list("room.house.id = ?1 and nextWateringDate <= ?2", houseId, LocalDate.now());
    }

    /**
     * Find all plants needing water today across all users.
     * Used by the daily watering reminder scheduler.
     */
    public static List<UserPlantEntity> findAllNeedingWaterToday() {
        return list("nextWateringDate <= ?1", LocalDate.now());
    }

    public static long countByUser(UUID userId) {
        return count("user.id", userId);
    }

    public static long countByRoom(UUID roomId) {
        return count("room.id", roomId);
    }

    /**
     * Check if plant needs watering based on last watered date and interval.
     */
    public boolean needsWatering() {
        if (lastWatered == null || wateringIntervalDays == null) {
            return true;
        }
        return lastWatered.plusDays(wateringIntervalDays).isBefore(OffsetDateTime.now());
    }

    /**
     * Calculate the next watering date based on last watering and interval.
     */
    public LocalDate getNextWateringDate() {
        if (lastWatered == null) {
            return LocalDate.now();
        }
        return lastWatered.toLocalDate().plusDays(wateringIntervalDays != null ? wateringIntervalDays : 7);
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
        if (acquiredAt == null) {
            acquiredAt = LocalDate.now();
        }
        if (wateringIntervalDays == null) {
            wateringIntervalDays = 7;
        }
        if (exposure == null) {
            exposure = Exposure.PARTIAL_SHADE;
        }
        // Calculate next watering date on creation
        calculateNextWateringDate();
    }

    @PreUpdate
    void onUpdate() {
        // Recalculate next watering date on any update
        calculateNextWateringDate();
    }

    /**
     * Calculate and update the next watering date.
     * Call this after watering or changing the interval.
     */
    public void calculateNextWateringDate() {
        int interval = wateringIntervalDays != null ? wateringIntervalDays : 7;
        if (lastWatered != null) {
            nextWateringDate = lastWatered.toLocalDate().plusDays(interval);
        } else {
            nextWateringDate = LocalDate.now().plusDays(interval);
        }
    }

    /**
     * Water the plant: update lastWatered, healthStatus, and recalculate
     * nextWateringDate.
     */
    public void water() {
        this.lastWatered = OffsetDateTime.now();
        // Watering doesn't magically cure sickness or fix repotting needs.
        // It mainly addresses the 'Thirsty' state which is dynamically calculated.
        calculateNextWateringDate();
    }
}
