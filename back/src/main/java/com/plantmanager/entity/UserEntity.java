package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

/**
 * User entity for authentication and authorization.
 * Maps to the existing 'app_user' table in the database.
 */
@Entity
@Table(name = "app_user")
public class UserEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "house_id")
    public HouseEntity house;

    // Keep houseId for backward compatibility and easy access
    @Column(name = "house_id", insertable = false, updatable = false)
    public UUID houseId;

    @Column(unique = true, nullable = false, length = 255)
    public String email;

    @Column(name = "password_hash", nullable = false, length = 255)
    public String passwordHash;

    @Column(name = "display_name", nullable = false, length = 100)
    public String displayName;

    @Column(nullable = false, columnDefinition = "user_role")
    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    public UserRole role = UserRole.MEMBER;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    @Column(name = "profile_photo_path", columnDefinition = "TEXT")
    public String profilePhotoPath;

    @Column(name = "password_reset_token")
    public String passwordResetToken;

    @Column(name = "password_reset_token_expiry")
    public OffsetDateTime passwordResetTokenExpiry;

    @Column(name = "email_verified", nullable = false)
    public boolean emailVerified = false;

    @Column(name = "email_verification_code", length = 6)
    public String emailVerificationCode;

    @Column(name = "email_verification_code_expiry")
    public OffsetDateTime emailVerificationCodeExpiry;

    public enum UserRole {
        OWNER,
        MEMBER,
        GUEST
    }

    // ===== Static finder methods (Active Record pattern) =====

    /**
     * Find a user by their email address.
     * 
     * @param email the email to search for
     * @return Optional containing the user if found
     */
    public static Optional<UserEntity> findByEmail(String email) {
        return find("email", email).firstResultOptional();
    }

    /**
     * Check if a user with the given email already exists.
     * 
     * @param email the email to check
     * @return true if email is already registered
     */
    public static boolean existsByEmail(String email) {
        return count("email", email) > 0;
    }

    public static Optional<UserEntity> findByPasswordResetToken(String token) {
        return find("passwordResetToken", token).firstResultOptional();
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
        if (role == null) {
            role = UserRole.MEMBER;
        }
    }
}
