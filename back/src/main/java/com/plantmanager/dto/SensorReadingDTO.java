package com.plantmanager.dto;

import com.plantmanager.entity.SensorReadingEntity;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

public record SensorReadingDTO(
        UUID id,
        BigDecimal value,
        String unit,
        OffsetDateTime recordedAt) {

    public static SensorReadingDTO from(SensorReadingEntity e) {
        return new SensorReadingDTO(e.id, e.value, e.unit, e.recordedAt);
    }
}
