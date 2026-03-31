package com.plantmanager.dto;

import com.plantmanager.entity.enums.RoomType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTO for creating a new room.
 */
public record CreateRoomDTO(
        @NotBlank(message = "Le nom de la piece est requis") @Size(max = 100, message = "Le nom de la piece doit contenir au maximum 100 caracteres") String name,

        @NotNull(message = "Le type de piece est requis") RoomType type) {
}
