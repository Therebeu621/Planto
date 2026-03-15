package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Junction entity for Many-to-Many relationship between User and House.
 * A user can belong to multiple houses and switch between them.
 */
@Entity
@Table(name = "user_house", uniqueConstraints = {
        @UniqueConstraint(columnNames = { "user_id", "house_id" })
})
public class UserHouseEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    public UserEntity user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "house_id", nullable = false)
    public HouseEntity house;

    @Column(columnDefinition = "user_role")
    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    public UserEntity.UserRole role = UserEntity.UserRole.MEMBER;

    @Column(name = "is_active")
    public boolean isActive = false;

    @Column(name = "joined_at")
    public OffsetDateTime joinedAt;

    // ===== Static finder methods =====

    /**
     * Find all houses for a user.
     */
    public static List<UserHouseEntity> findByUser(UUID userId) {
        return list("user.id", userId);
    }

    /**
     * Find the active house for a user.
     */
    public static UserHouseEntity findActiveByUser(UUID userId) {
        return find("user.id = ?1 and isActive = true", userId).firstResult();
    }

    /**
     * Find a specific user-house membership.
     */
    public static UserHouseEntity findByUserAndHouse(UUID userId, UUID houseId) {
        return find("user.id = ?1 and house.id = ?2", userId, houseId).firstResult();
    }

    /**
     * Find all members of a house.
     */
    public static List<UserHouseEntity> findByHouse(UUID houseId) {
        return list("house.id", houseId);
    }

    /**
     * Count members in a house.
     */
    public static long countByHouse(UUID houseId) {
        return count("house.id", houseId);
    }

    @PrePersist
    void onCreate() {
        if (joinedAt == null) {
            joinedAt = OffsetDateTime.now();
        }
    }
}
