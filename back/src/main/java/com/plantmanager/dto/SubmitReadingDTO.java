package com.plantmanager.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record SubmitReadingDTO(
        @NotNull(message = "Value is required")
        BigDecimal value) {
}
