package com.plantmanager.dto;

import com.plantmanager.entity.enums.RoomType;
import jakarta.validation.constraints.Size;

/**
 * DTO for updating an existing room.
 * All fields are optional.
 */
public record UpdateRoomDTO(
        @Size(max = 100, message = "Room name must be at most 100 characters") String name,

        RoomType type) {
}
