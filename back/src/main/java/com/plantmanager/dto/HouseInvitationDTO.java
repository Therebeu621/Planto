package com.plantmanager.dto;

import com.plantmanager.entity.HouseInvitationEntity;
import com.plantmanager.entity.enums.InvitationStatus;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for house invitation/join request responses.
 */
public record HouseInvitationDTO(
        UUID id,
        UUID houseId,
        String houseName,
        UUID requesterId,
        String requesterName,
        String requesterEmail,
        InvitationStatus status,
        UUID respondedById,
        String respondedByName,
        OffsetDateTime createdAt,
        OffsetDateTime respondedAt) {

    public static HouseInvitationDTO from(HouseInvitationEntity entity) {
        return new HouseInvitationDTO(
                entity.id,
                entity.house.id,
                entity.house.name,
                entity.requester.id,
                entity.requester.displayName,
                entity.requester.email,
                entity.status,
                entity.respondedBy != null ? entity.respondedBy.id : null,
                entity.respondedBy != null ? entity.respondedBy.displayName : null,
                entity.createdAt,
                entity.respondedAt);
    }
}
