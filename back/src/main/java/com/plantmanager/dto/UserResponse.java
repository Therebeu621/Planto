package com.plantmanager.dto;

import com.plantmanager.entity.UserEntity;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for user response (excludes sensitive data like password).
 */
public record UserResponse(
        UUID id,
        String email,
        String displayName,
        String role,
        OffsetDateTime createdAt,
        String profilePhotoUrl,
        boolean emailVerified) {
    /**
     * Create a UserResponse from a UserEntity.
     *
     * @param entity the user entity
     * @return UserResponse without sensitive data
     */
    public static UserResponse from(UserEntity entity) {
        String photoUrl = null;
        if (entity.profilePhotoPath != null && !entity.profilePhotoPath.isBlank()) {
            photoUrl = "/api/v1/files/" + entity.profilePhotoPath;
        }
        return new UserResponse(
                entity.id,
                entity.email,
                entity.displayName,
                entity.role.name(),
                entity.createdAt,
                photoUrl,
                entity.emailVerified);
    }
}
