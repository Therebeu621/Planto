package com.plantmanager.entity;

import com.plantmanager.entity.enums.InvitationStatus;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Entity representing a house join request.
 * When a user enters an invite code, a pending invitation is created.
 * The house owner must accept or decline.
 */
@Entity
@Table(name = "house_invitation")
public class HouseInvitationEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "house_id", nullable = false)
    public HouseEntity house;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requester_id", nullable = false)
    public UserEntity requester;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "invitation_status")
    public InvitationStatus status = InvitationStatus.PENDING;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "responded_by")
    public UserEntity respondedBy;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    @Column(name = "responded_at")
    public OffsetDateTime respondedAt;

    // ===== Static finder methods =====

    public static List<HouseInvitationEntity> findPendingByHouse(UUID houseId) {
        return list("house.id = ?1 and status = ?2 order by createdAt desc", houseId, InvitationStatus.PENDING);
    }

    public static List<HouseInvitationEntity> findPendingByRequester(UUID requesterId) {
        return list("requester.id = ?1 and status = ?2 order by createdAt desc", requesterId, InvitationStatus.PENDING);
    }

    public static HouseInvitationEntity findPendingByRequesterAndHouse(UUID requesterId, UUID houseId) {
        return find("requester.id = ?1 and house.id = ?2 and status = ?3",
                requesterId, houseId, InvitationStatus.PENDING).firstResult();
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }
}
