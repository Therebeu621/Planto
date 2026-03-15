package com.plantmanager.entity;

import com.plantmanager.entity.enums.NotificationType;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Notification entity for in-app notifications.
 * Maps to the 'notification' table.
 */
@Entity
@Table(name = "notification")
public class NotificationEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    public UserEntity user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "plant_id")
    public UserPlantEntity plant;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "notification_type")
    public NotificationType type;

    @Column(nullable = false, columnDefinition = "TEXT")
    public String message;

    @Column(name = "read")
    public Boolean read = false;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    // ===== Static finder methods =====

    public static List<NotificationEntity> findByUser(UUID userId) {
        return list("user.id = ?1 order by createdAt desc", userId);
    }

    public static List<NotificationEntity> findUnreadByUser(UUID userId) {
        return list("user.id = ?1 and read = false order by createdAt desc", userId);
    }

    public static long countUnreadByUser(UUID userId) {
        return count("user.id = ?1 and read = false", userId);
    }

    public static int markAllAsReadByUser(UUID userId) {
        return update("read = true where user.id = ?1 and read = false", userId);
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
        if (read == null) {
            read = false;
        }
    }
}
