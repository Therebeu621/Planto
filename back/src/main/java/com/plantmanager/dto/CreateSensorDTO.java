package com.plantmanager.dto;

import com.plantmanager.entity.enums.SensorType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CreateSensorDTO(
        @NotNull(message = "Sensor type is required")
        SensorType sensorType,

        @NotBlank(message = "Device ID is required")
        @Size(max = 100)
        String deviceId,

        @Size(max = 100)
        String label,

        UUID plantId) {
}
