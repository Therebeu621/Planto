package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Pot stock entity representing available pots in a house.
 * Maps to the 'pot_stock' table.
 */
@Entity
@Table(name = "pot_stock")
public class PotStockEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "house_id", nullable = false)
    public HouseEntity house;

    @Column(name = "diameter_cm", nullable = false, precision = 5, scale = 1)
    public BigDecimal diameterCm;

    @Column(nullable = false)
    public int quantity = 1;

    @Column(length = 100)
    public String label;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    @Column(name = "updated_at")
    public OffsetDateTime updatedAt;

    // ===== Static finder methods =====

    public static List<PotStockEntity> findByHouse(UUID houseId) {
        return list("house.id = ?1 order by diameterCm asc", houseId);
    }

    public static Optional<PotStockEntity> findByHouseAndDiameter(UUID houseId, BigDecimal diameterCm) {
        return find("house.id = ?1 and diameterCm = ?2", houseId, diameterCm).firstResultOptional();
    }

    /**
     * Find pots with available stock (quantity > 0) for a house.
     */
    public static List<PotStockEntity> findAvailableByHouse(UUID houseId) {
        return list("house.id = ?1 and quantity > 0 order by diameterCm asc", houseId);
    }

    /**
     * Find pots larger than a given diameter (for repotting suggestions).
     */
    public static List<PotStockEntity> findLargerPots(UUID houseId, BigDecimal currentDiameter) {
        return list("house.id = ?1 and quantity > 0 and diameterCm > ?2 order by diameterCm asc",
                houseId, currentDiameter);
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
        updatedAt = OffsetDateTime.now();
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
