package com.plantmanager.dto;

import com.plantmanager.entity.enums.CareAction;
import jakarta.validation.constraints.NotNull;

/**
 * DTO for creating a care log entry.
 */
public record CreateCareLogDTO(
        @NotNull(message = "Action is required") CareAction action,
        String notes) {
}
