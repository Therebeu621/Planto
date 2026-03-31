package com.plantmanager.entity;

import com.plantmanager.entity.enums.VacationStatus;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Entity for vacation mode / temporary delegation.
 * When a user goes on vacation, they delegate plant care to another house member.
 * The delegate receives watering reminders and can water the delegator's plants.
 */
@Entity
@Table(name = "vacation_delegation")
public class VacationDelegationEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "house_id", nullable = false)
    public HouseEntity house;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "delegator_id", nullable = false)
    public UserEntity delegator;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "delegate_id", nullable = false)
    public UserEntity delegate;

    @Column(name = "start_date", nullable = false)
    public LocalDate startDate;

    @Column(name = "end_date", nullable = false)
    public LocalDate endDate;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "vacation_status")
    public VacationStatus status = VacationStatus.ACTIVE;

    @Column(columnDefinition = "TEXT")
    public String message;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    // ===== Static finder methods =====

    /**
     * Find active delegation where this user is the delegator (on vacation).
     */
    public static VacationDelegationEntity findActiveDelegationByDelegator(UUID userId, UUID houseId) {
        return find("delegator.id = ?1 and house.id = ?2 and status = ?3",
                userId, houseId, VacationStatus.ACTIVE).firstResult();
    }

    /**
     * Find an active delegation for a delegator that overlaps a requested period.
     * Intervals are inclusive: [existing.startDate, existing.endDate] overlaps
     * [startDate, endDate] when existing.startDate <= endDate and
     * existing.endDate >= startDate.
     */
    public static VacationDelegationEntity findOverlappingActiveDelegationByDelegator(
            UUID userId, UUID houseId, LocalDate startDate, LocalDate endDate) {
        return find(
                "delegator.id = ?1 and house.id = ?2 and status = ?3 and startDate <= ?4 and endDate >= ?5",
                userId, houseId, VacationStatus.ACTIVE, endDate, startDate
        ).firstResult();
    }

    /**
     * Find all active delegations where this user is the delegate (taking care).
     */
    public static List<VacationDelegationEntity> findActiveDelegationsByDelegate(UUID userId, UUID houseId) {
        return list("delegate.id = ?1 and house.id = ?2 and status = ?3",
                userId, houseId, VacationStatus.ACTIVE);
    }

    /**
     * Find all active delegations in a house.
     */
    public static List<VacationDelegationEntity> findActiveByHouse(UUID houseId) {
        return list("house.id = ?1 and status = ?2", houseId, VacationStatus.ACTIVE);
    }

    /**
     * Find all expired delegations (end_date < today and still ACTIVE).
     */
    public static List<VacationDelegationEntity> findExpired() {
        return list("status = ?1 and endDate < ?2", VacationStatus.ACTIVE, LocalDate.now());
    }

    /**
     * Check if a user is currently on vacation in a house.
     */
    public static boolean isOnVacation(UUID userId, UUID houseId) {
        return count("delegator.id = ?1 and house.id = ?2 and status = ?3 and startDate <= ?4 and endDate >= ?4",
                userId, houseId, VacationStatus.ACTIVE, LocalDate.now()) > 0;
    }

    /**
     * Find active delegation for a specific delegator (any house).
     */
    public static VacationDelegationEntity findActiveDelegationByDelegator(UUID userId) {
        return find("delegator.id = ?1 and status = ?2 and startDate <= ?3 and endDate >= ?3",
                userId, VacationStatus.ACTIVE, LocalDate.now()).firstResult();
    }

    /**
     * Find all users for whom this delegate is currently responsible.
     */
    public static List<VacationDelegationEntity> findActiveDelegationsForDelegate(UUID delegateId) {
        return list("delegate.id = ?1 and status = ?2 and startDate <= ?3 and endDate >= ?3",
                delegateId, VacationStatus.ACTIVE, LocalDate.now());
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }
}
