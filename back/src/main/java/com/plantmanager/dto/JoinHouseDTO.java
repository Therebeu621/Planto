package com.plantmanager.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * DTO for joining a house via invite code.
 */
public record JoinHouseDTO(
        @NotBlank(message = "Le code d'invitation est requis") @Size(min = 8, max = 8, message = "Le code d'invitation doit contenir 8 caracteres") String inviteCode) {
}
