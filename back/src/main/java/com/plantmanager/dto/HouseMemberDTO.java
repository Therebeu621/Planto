package com.plantmanager.dto;

import com.plantmanager.entity.UserHouseEntity;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for house member information.
 */
public record HouseMemberDTO(
        UUID userId,
        String displayName,
        String email,
        String profilePhotoUrl,
        String role,
        OffsetDateTime joinedAt,
        boolean isActive) {

    /**
     * Create from UserHouseEntity.
     */
    public static HouseMemberDTO from(UserHouseEntity membership) {
        // Build profile photo URL like UserResponse does
        String photoUrl = null;
        if (membership.user.profilePhotoPath != null && !membership.user.profilePhotoPath.isBlank()) {
            photoUrl = "/api/v1/files/" + membership.user.profilePhotoPath;
        }

        return new HouseMemberDTO(
                membership.user.id,
                membership.user.displayName,
                membership.user.email,
                photoUrl,
                membership.role.name(),
                membership.joinedAt,
                membership.isActive);
    }
}
