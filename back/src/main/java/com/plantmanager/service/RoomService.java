package com.plantmanager.service;

import com.plantmanager.dto.CreateRoomDTO;
import com.plantmanager.dto.RoomResponseDTO;
import com.plantmanager.dto.UpdateRoomDTO;
import com.plantmanager.entity.HouseEntity;
import com.plantmanager.entity.RoomEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserHouseEntity;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;

import org.hibernate.Hibernate;

import java.util.List;
import java.util.UUID;

/**
 * Service for room business logic.
 */
@ApplicationScoped
public class RoomService {

    private static final String PHOTO_BASE_URL = "/api/v1/files";

    /**
     * Get the active house for a user.
     */
    private HouseEntity getActiveHouse(UUID userId) {
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership == null) {
            // Fallback to old house_id on user for backward compatibility
            UserEntity user = UserEntity.findById(userId);
            if (user != null && user.house != null) {
                return user.house;
            }
            return null;
        }
        return membership.house;
    }

    /**
     * Get all rooms for a user's active house with plants.
     */
    public List<RoomResponseDTO> getRoomsByUser(UUID userId, boolean includePlants) {
        HouseEntity house = getActiveHouse(userId);
        if (house == null) {
            return List.of();
        }

        List<RoomEntity> rooms = RoomEntity.findByHouse(house.id);

        if (includePlants) {
            return rooms.stream()
                    .map(room -> RoomResponseDTO.from(room, PHOTO_BASE_URL))
                    .toList();
        } else {
            return rooms.stream()
                    .map(RoomResponseDTO::fromWithoutPlants)
                    .toList();
        }
    }

    /**
     * Get a room by ID with ownership check.
     */
    public RoomEntity getRoomById(UUID userId, UUID roomId) {
        HouseEntity house = getActiveHouse(userId);
        if (house == null) {
            throw new ForbiddenException("You must join a house first");
        }

        RoomEntity room = RoomEntity.findById(roomId);
        if (room == null) {
            throw new NotFoundException("Room not found");
        }

        // Verify room belongs to user's active house
        if (!room.house.id.equals(house.id)) {
            throw new ForbiddenException("You don't have access to this room");
        }

        return room;
    }

    /**
     * Get room details with plants.
     */
    public RoomResponseDTO getRoomDetail(UUID userId, UUID roomId) {
        RoomEntity room = getRoomById(userId, roomId);
        return RoomResponseDTO.from(room, PHOTO_BASE_URL);
    }

    /**
     * Create a new room.
     */
    @Transactional
    public RoomEntity createRoom(UUID userId, CreateRoomDTO dto) {
        HouseEntity house = getActiveHouse(userId);
        if (house == null) {
            throw new ForbiddenException("You must join a house before creating rooms");
        }

        // Auto-rename if duplicate: "Salon" -> "Salon 2" -> "Salon 3"...
        String baseName = dto.name();
        String finalName = baseName;
        int suffix = 2;
        while (RoomEntity.count("house = ?1 and name = ?2", house, finalName) > 0) {
            finalName = baseName + " " + suffix;
            suffix++;
        }

        RoomEntity room = new RoomEntity();
        room.house = house;
        room.name = finalName;
        room.type = dto.type();

        room.persist();
        return room;
    }

    /**
     * Update a room.
     */
    @Transactional
    public RoomEntity updateRoom(UUID userId, UUID roomId, UpdateRoomDTO dto) {
        RoomEntity room = getRoomById(userId, roomId);

        if (dto.name() != null) {
            room.name = dto.name();
        }
        if (dto.type() != null) {
            room.type = dto.type();
        }

        // Initialize plants collection within transaction to avoid lazy init errors
        // when the resource serializes a DTO outside of the transactional context.
        if (room.plants != null) {
            Hibernate.initialize(room.plants);
        }

        return room;
    }

    /**
     * Delete a room.
     */
    @Transactional
    public void deleteRoom(UUID userId, UUID roomId) {
        RoomEntity room = getRoomById(userId, roomId);

        // Plants in this room will have room_id set to NULL (due to SET NULL on delete)
        room.delete();
    }
}
