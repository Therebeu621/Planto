package com.plantmanager.dto;

import com.plantmanager.entity.IotSensorEntity;
import com.plantmanager.entity.SensorReadingEntity;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

public record IotSensorDTO(
        UUID id,
        String sensorType,
        String sensorTypeDisplay,
        String deviceId,
        String label,
        boolean isActive,
        UUID plantId,
        String plantNickname,
        BigDecimal lastValue,
        String unit,
        OffsetDateTime lastReadingAt,
        OffsetDateTime createdAt) {

    public static IotSensorDTO from(IotSensorEntity e) {
        SensorReadingEntity latest = SensorReadingEntity.findLatestBySensor(e.id);
        return new IotSensorDTO(
                e.id,
                e.sensorType.name(),
                e.sensorType.getDisplayName(),
                e.deviceId,
                e.label,
                e.isActive,
                e.plant != null ? e.plant.id : null,
                e.plant != null ? e.plant.nickname : null,
                latest != null ? latest.value : null,
                e.sensorType.getUnit(),
                latest != null ? latest.recordedAt : null,
                e.createdAt);
    }
}
