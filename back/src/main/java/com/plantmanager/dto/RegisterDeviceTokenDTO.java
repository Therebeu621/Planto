package com.plantmanager.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * DTO for registering an FCM device token.
 */
public record RegisterDeviceTokenDTO(
        @NotBlank(message = "FCM token is required")
        String fcmToken,
        String deviceInfo) {
}
