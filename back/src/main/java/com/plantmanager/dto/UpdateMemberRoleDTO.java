package com.plantmanager.dto;

import jakarta.validation.constraints.NotNull;

/**
 * DTO for updating a member's role in a house.
 */
public record UpdateMemberRoleDTO(
        @NotNull(message = "Role is required")
        String role) {
}
