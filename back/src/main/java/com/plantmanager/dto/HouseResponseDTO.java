package com.plantmanager.dto;

import com.plantmanager.entity.HouseEntity;
import com.plantmanager.entity.UserHouseEntity;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for house response.
 */
public record HouseResponseDTO(
        UUID id,
        String name,
        String inviteCode,
        int memberCount,
        int roomCount,
        boolean isActive,
        String role,
        OffsetDateTime joinedAt) {
    /**
     * Create from HouseEntity with membership info.
     */
    public static HouseResponseDTO from(HouseEntity house, UserHouseEntity membership) {
        // Count members from UserHouseEntity (the actual membership table)
        int memberCount = (int) UserHouseEntity.countByHouse(house.id);

        return new HouseResponseDTO(
                house.id,
                house.name,
                house.inviteCode,
                memberCount,
                house.rooms != null ? house.rooms.size() : 0,
                membership != null && membership.isActive,
                membership != null ? membership.role.name() : null,
                membership != null ? membership.joinedAt : null);
    }

    /**
     * Create from HouseEntity only (for new house creation).
     */
    public static HouseResponseDTO from(HouseEntity house) {
        // Count members from UserHouseEntity
        int memberCount = (int) UserHouseEntity.countByHouse(house.id);

        return new HouseResponseDTO(
                house.id,
                house.name,
                house.inviteCode,
                memberCount > 0 ? memberCount : 1, // At least 1 (the creator)
                house.rooms != null ? house.rooms.size() : 0,
                true,
                "OWNER",
                house.createdAt);
    }
}
