package com.plantmanager.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * DTO for creating or adding to pot stock.
 */
public record CreatePotStockDTO(
        @NotNull(message = "Le diametre est requis")
        @DecimalMin(value = "1.0", message = "Le diametre doit etre au moins 1 cm")
        BigDecimal diameterCm,

        @Min(value = 1, message = "La quantite doit etre au moins 1")
        int quantity,

        @Size(max = 100, message = "Le label ne doit pas depasser 100 caracteres")
        String label) {
}
