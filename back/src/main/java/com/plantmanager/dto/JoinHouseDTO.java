package com.plantmanager.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * DTO for joining a house via invite code.
 */
public record JoinHouseDTO(
        @NotBlank(message = "Invite code is required") @Size(min = 8, max = 8, message = "Invite code must be 8 characters") String inviteCode) {
}
