package com.plantmanager.entity;

import com.plantmanager.entity.enums.CareAction;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Care log entity for recording plant care actions.
 * Maps to the 'care_log' table.
 */
@Entity
@Table(name = "care_log")
public class CareLogEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "plant_id", nullable = false)
    public UserPlantEntity plant;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    public UserEntity user;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "care_action")
    public CareAction action;

    @Column(columnDefinition = "TEXT")
    public String notes;

    @Column(name = "performed_at")
    public OffsetDateTime performedAt;

    // ===== Static finder methods =====

    public static List<CareLogEntity> findByPlant(UUID plantId) {
        return list("plant.id = ?1 order by performedAt desc", plantId);
    }

    public static List<CareLogEntity> findByPlantLimited(UUID plantId, int limit) {
        return find("plant.id = ?1 order by performedAt desc", plantId)
                .page(0, limit)
                .list();
    }

    public static List<CareLogEntity> findByUser(UUID userId) {
        return list("user.id = ?1 order by performedAt desc", userId);
    }

    public static List<CareLogEntity> findByPlantAndAction(UUID plantId, CareAction action) {
        return list("plant.id = ?1 and action = ?2 order by performedAt desc", plantId, action);
    }

    /**
     * Find recent care logs for all plants in a house (house-wide activity feed).
     * Joins through plant -> user -> user_house to get all activity in a house.
     */
    public static List<CareLogEntity> findByHouse(UUID houseId, int limit) {
        return find(
                "SELECT cl FROM CareLogEntity cl " +
                "JOIN cl.plant p " +
                "JOIN UserHouseEntity uh ON uh.user.id = p.user.id AND uh.house.id = ?1 " +
                "ORDER BY cl.performedAt DESC",
                houseId)
                .page(0, limit)
                .list();
    }

    @PrePersist
    void onCreate() {
        if (performedAt == null) {
            performedAt = OffsetDateTime.now();
        }
    }
}
