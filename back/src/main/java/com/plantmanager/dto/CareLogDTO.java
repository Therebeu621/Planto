package com.plantmanager.dto;

import com.plantmanager.entity.CareLogEntity;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for care log responses.
 */
public record CareLogDTO(
        UUID id,
        String action,
        String notes,
        OffsetDateTime performedAt,
        UUID plantId,
        String plantNickname,
        UUID performedById,
        String performedByName) {

    public static CareLogDTO from(CareLogEntity entity) {
        return new CareLogDTO(
                entity.id,
                entity.action.name(),
                entity.notes,
                entity.performedAt,
                entity.plant != null ? entity.plant.id : null,
                entity.plant != null ? entity.plant.nickname : null,
                entity.user != null ? entity.user.id : null,
                entity.user != null ? entity.user.displayName : null);
    }
}
