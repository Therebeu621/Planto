package com.plantmanager.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

/**
 * DTO for the repotting action.
 * Specifies the new pot diameter. The old pot is returned to stock automatically.
 */
public record RepotDTO(
        @NotNull(message = "Le nouveau diametre est requis")
        @DecimalMin(value = "1.0", message = "Le diametre doit etre au moins 1 cm")
        BigDecimal newDiameterCm,

        /** Optional notes about the repotting */
        String notes) {
}
