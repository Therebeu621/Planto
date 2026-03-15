package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Entity for storing FCM device tokens for push notifications.
 * A user can have multiple devices, each with its own token.
 */
@Entity
@Table(name = "device_token")
public class DeviceTokenEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    public UserEntity user;

    @Column(name = "fcm_token", nullable = false, unique = true)
    public String fcmToken;

    @Column(name = "device_info")
    public String deviceInfo;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    @Column(name = "updated_at")
    public OffsetDateTime updatedAt;

    // ===== Static finder methods =====

    public static List<DeviceTokenEntity> findByUser(UUID userId) {
        return list("user.id", userId);
    }

    public static DeviceTokenEntity findByToken(String fcmToken) {
        return find("fcmToken", fcmToken).firstResult();
    }

    public static long deleteByToken(String fcmToken) {
        return delete("fcmToken", fcmToken);
    }

    /**
     * Find all FCM tokens for a list of user IDs.
     */
    public static List<DeviceTokenEntity> findByUsers(List<UUID> userIds) {
        if (userIds == null || userIds.isEmpty()) return List.of();
        return list("user.id in ?1", userIds);
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = OffsetDateTime.now();
        if (updatedAt == null) updatedAt = OffsetDateTime.now();
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
