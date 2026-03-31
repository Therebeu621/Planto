package com.plantmanager.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * DTO for creating a new house.
 */
public record CreateHouseDTO(
        @NotBlank(message = "Le nom de la maison est requis") @Size(max = 100, message = "Le nom de la maison doit contenir au maximum 100 caracteres") String name) {
}
