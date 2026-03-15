package com.plantmanager.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * DTO for creating a new house.
 */
public record CreateHouseDTO(
        @NotBlank(message = "House name is required") @Size(max = 100, message = "House name must be at most 100 characters") String name) {
}
