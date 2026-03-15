package com.plantmanager.dto;

import jakarta.validation.constraints.Size;

public record UpdateProfileDTO(
        @Size(min = 2, max = 100, message = "Display name must be between 2 and 100 characters")
        String displayName) {
}
