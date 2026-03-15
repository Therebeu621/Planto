package com.plantmanager.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * DTO for refresh token request.
 * Used for POST /auth/refresh endpoint.
 */
public record RefreshTokenRequest(
        @NotBlank(message = "Refresh token is required")
        String refreshToken) {
}
