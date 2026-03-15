package com.plantmanager.dto;

import com.plantmanager.entity.enums.CultureStatus;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record UpdateCultureStatusDTO(
        @NotNull(message = "New status is required")
        CultureStatus newStatus,

        BigDecimal heightCm,
        String notes,
        String harvestQuantity) {
}
