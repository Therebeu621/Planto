package com.plantmanager.dto;

import jakarta.validation.constraints.NotBlank;

public record VerifyEmailDTO(
        @NotBlank(message = "Verification code is required")
        String code) {
}
