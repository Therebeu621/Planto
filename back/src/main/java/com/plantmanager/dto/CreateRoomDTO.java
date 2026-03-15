package com.plantmanager.dto;

import com.plantmanager.entity.enums.RoomType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTO for creating a new room.
 */
public record CreateRoomDTO(
        @NotBlank(message = "Room name is required") @Size(max = 100, message = "Room name must be at most 100 characters") String name,

        @NotNull(message = "Room type is required") RoomType type) {
}
