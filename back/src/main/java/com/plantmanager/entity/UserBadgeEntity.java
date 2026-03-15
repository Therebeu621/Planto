package com.plantmanager.entity;

import com.plantmanager.entity.enums.BadgeType;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Badge unlocked by a user.
 */
@Entity
@Table(name = "user_badge",
        uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "badge"}))
public class UserBadgeEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    public UserEntity user;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "badge_type")
    public BadgeType badge;

    @Column(name = "unlocked_at")
    public OffsetDateTime unlockedAt;

    // ===== Static finders =====

    public static List<UserBadgeEntity> findByUser(UUID userId) {
        return list("user.id = ?1 order by unlockedAt desc", userId);
    }

    public static boolean hasBadge(UUID userId, BadgeType badge) {
        return count("user.id = ?1 and badge = ?2", userId, badge) > 0;
    }

    @PrePersist
    void onCreate() {
        if (unlockedAt == null) {
            unlockedAt = OffsetDateTime.now();
        }
    }
}
