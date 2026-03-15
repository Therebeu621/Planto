package com.plantmanager.dto;

import com.plantmanager.entity.CultureGrowthLogEntity;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

public record GrowthLogDTO(
        UUID id,
        String oldStatus,
        String newStatus,
        String newStatusDisplay,
        BigDecimal heightCm,
        String notes,
        String photoPath,
        String userName,
        OffsetDateTime loggedAt) {

    public static GrowthLogDTO from(CultureGrowthLogEntity e) {
        return new GrowthLogDTO(
                e.id,
                e.oldStatus != null ? e.oldStatus.name() : null,
                e.newStatus.name(),
                e.newStatus.getDisplayName(),
                e.heightCm,
                e.notes,
                e.photoPath,
                e.user != null ? e.user.displayName : null,
                e.loggedAt);
    }
}
