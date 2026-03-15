package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;

import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * House entity representing a household/family.
 * Users join a house to share plants.
 * Maps to the 'house' table.
 */
@Entity
@Table(name = "house")
public class HouseEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @Column(nullable = false, length = 100)
    public String name;

    @Column(name = "invite_code", unique = true, nullable = false, length = 8)
    public String inviteCode;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    // One-to-Many: House has many Users
    @OneToMany(mappedBy = "house", fetch = FetchType.LAZY)
    public List<UserEntity> members = new ArrayList<>();

    // One-to-Many: House has many Rooms
    @OneToMany(mappedBy = "house", fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
    public List<RoomEntity> rooms = new ArrayList<>();

    // ===== Static finder methods =====

    public static Optional<HouseEntity> findByInviteCode(String code) {
        return find("inviteCode", code).firstResultOptional();
    }

    public static boolean existsByInviteCode(String code) {
        return count("inviteCode", code) > 0;
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
        if (inviteCode == null) {
            inviteCode = generateInviteCode();
        }
    }

    private String generateInviteCode() {
        // Generate 8 character alphanumeric code
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        SecureRandom random = new SecureRandom();
        StringBuilder code = new StringBuilder(8);
        for (int i = 0; i < 8; i++) {
            code.append(chars.charAt(random.nextInt(chars.length())));
        }
        return code.toString();
    }
}
