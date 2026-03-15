package com.plantmanager.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.UUID;

/**
 * DTO for activating vacation mode.
 */
public record VacationRequestDTO(
        @NotNull(message = "Delegate user ID is required")
        UUID delegateId,

        @NotNull(message = "Start date is required")
        LocalDate startDate,

        @NotNull(message = "End date is required")
        LocalDate endDate,

        /** Optional message for the delegate */
        String message) {
}
