package com.plantmanager.dto;

import jakarta.validation.constraints.Min;

/**
 * DTO for updating pot stock quantity.
 */
public record UpdatePotStockDTO(
        @Min(value = 0, message = "La quantite ne peut pas etre negative")
        int quantity) {
}
