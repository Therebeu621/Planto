package com.plantmanager.service;

import com.plantmanager.dto.CareLogDTO;
import com.plantmanager.dto.CreateCareLogDTO;
import com.plantmanager.dto.CreatePlantDTO;
import com.plantmanager.dto.PlantDetailDTO;
import com.plantmanager.dto.PlantResponseDTO;
import com.plantmanager.dto.UpdatePlantDTO;
import com.plantmanager.entity.*;
import com.plantmanager.entity.enums.CareAction;
import com.plantmanager.entity.enums.HealthStatus;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.ForbiddenException;

import org.hibernate.Hibernate;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Service for plant business logic.
 */
@ApplicationScoped
public class PlantService {

    @Inject
    FcmService fcmService;

    @Inject
    VacationService vacationService;

    @Inject
    GamificationService gamificationService;

    /**
     * Create a new plant for a user.
     */
    @Transactional
    public UserPlantEntity createPlant(UUID userId, CreatePlantDTO dto) {
        UserEntity user = UserEntity.findById(userId);
        if (user == null) {
            throw new NotFoundException("User not found");
        }

        UserPlantEntity plant = new UserPlantEntity();
        plant.user = user;
        plant.nickname = dto.nickname();
        plant.wateringIntervalDays = dto.getWateringIntervalOrDefault();
        plant.exposure = dto.getExposureOrDefault();
        plant.notes = dto.notes();

        // Health flags from DTO (default to false if not provided)
        plant.isSick = dto.isSick() != null ? dto.isSick() : false;
        plant.isWilted = dto.isWilted() != null ? dto.isWilted() : false;
        plant.needsRepotting = dto.needsRepotting() != null ? dto.needsRepotting() : false;

        // Pot diameter
        if (dto.potDiameterCm() != null) {
            plant.potDiameterCm = dto.potDiameterCm();
        }

        // Set last watered date if provided (affects nextWateringDate calculation)
        if (dto.lastWatered() != null) {
            plant.lastWatered = dto.lastWatered();
        }

        // Map photoUrl from DTO to photoPath in entity
        if (dto.photoUrl() != null && !dto.photoUrl().isEmpty()) {
            plant.photoPath = dto.photoUrl();
        }

        // Map custom species name
        if (dto.customSpecies() != null && !dto.customSpecies().isEmpty()) {
            plant.customSpecies = dto.customSpecies();
        }

        // Associate with room if provided
        if (dto.roomId() != null) {
            RoomEntity room = RoomEntity.findById(dto.roomId());
            if (room == null) {
                throw new NotFoundException("Room not found");
            }
            // Verify room belongs to user's active house
            UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
            UUID activeHouseId = membership != null ? membership.house.id : (user.house != null ? user.house.id : null);
            if (activeHouseId == null || !room.house.id.equals(activeHouseId)) {
                throw new ForbiddenException("Room does not belong to your active house");
            }
            plant.room = room;
        }

        // Associate with species if provided
        if (dto.speciesId() != null) {
            SpeciesCacheEntity species = SpeciesCacheEntity.findById(dto.speciesId());
            if (species == null) {
                throw new NotFoundException("Species not found");
            }
            plant.species = species;
        }

        plant.persist();

        // Gamification: XP for adding a plant
        gamificationService.onPlantAdded(userId);

        // Send push notification to house members
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership != null) {
            String displayName = user != null ? user.displayName : "Quelqu'un";
            fcmService.sendToHouseMembers(
                    membership.house.id,
                    userId,
                    "Nouvelle plante",
                    displayName + " a ajoute " + plant.nickname,
                    Map.of("type", "PLANT_ADDED", "plantId", plant.id.toString())
            );
        }

        return plant;
    }

    /**
     * Get all plants for a user with optional filters.
     */
    public List<PlantResponseDTO> getPlantsByUser(UUID userId, UUID roomId, HealthStatus status) {
        List<UserPlantEntity> plants;

        if (roomId != null) {
            plants = UserPlantEntity.findByUserAndRoom(userId, roomId);
        } else {
            plants = UserPlantEntity.findByUser(userId);
        }

        return plants.stream()
                .map(PlantResponseDTO::from)
                .toList();
    }

    /**
     * Search plants by nickname.
     */
    public List<PlantResponseDTO> searchPlants(UUID userId, String query) {
        if (query == null || query.length() < 2) {
            return List.of();
        }
        return UserPlantEntity.searchByNickname(userId, query).stream()
                .map(PlantResponseDTO::from)
                .toList();
    }

    /**
     * Get a plant by ID with ownership or delegation check.
     * Allows access if the user owns the plant OR is a delegate for the plant owner (vacation mode).
     * Used for write endpoints (update, delete, water, care-log creation, photo management).
     */
    public UserPlantEntity getPlantById(UUID userId, UUID plantId) {
        UserPlantEntity plant = UserPlantEntity.findById(plantId);
        if (plant == null) {
            throw new NotFoundException("Plant not found");
        }
        if (!plant.user.id.equals(userId)) {
            // Check if user is a delegate for the plant owner
            List<UUID> delegatorIds = vacationService.getDelegatorIdsForDelegate(userId);
            if (!delegatorIds.contains(plant.user.id)) {
                throw new ForbiddenException("You don't have access to this plant");
            }
        }
        return plant;
    }

    /**
     * Get a plant by ID with read-only access.
     * Allows access if the user owns the plant, is a vacation delegate,
     * OR is a member of the same house (via the plant's room).
     */
    public UserPlantEntity getPlantByIdReadOnly(UUID userId, UUID plantId) {
        UserPlantEntity plant = UserPlantEntity.findById(plantId);
        if (plant == null) {
            throw new NotFoundException("Plant not found");
        }
        // Owner or delegate: full access
        if (plant.user.id.equals(userId)) {
            return plant;
        }
        List<UUID> delegatorIds = vacationService.getDelegatorIdsForDelegate(userId);
        if (delegatorIds.contains(plant.user.id)) {
            return plant;
        }
        // Housemate: read access via the plant's room
        if (plant.room != null) {
            Hibernate.initialize(plant.room);
            if (plant.room.house != null) {
                UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, plant.room.house.id);
                if (membership != null) {
                    return plant;
                }
            }
        }
        throw new ForbiddenException("You don't have access to this plant");
    }

    /**
     * Check if a user can manage (write) a plant.
     * True if the user owns the plant or is a vacation delegate.
     * Must match the access rules of getPlantById() to avoid UI/backend mismatch.
     */
    public boolean canManagePlant(UUID userId, UserPlantEntity plant) {
        if (plant.user.id.equals(userId)) {
            return true;
        }
        List<UUID> delegatorIds = vacationService.getDelegatorIdsForDelegate(userId);
        return delegatorIds.contains(plant.user.id);
    }

    /**
     * Get detailed plant information.
     */
    public PlantDetailDTO getPlantDetail(UUID userId, UUID plantId) {
        UserPlantEntity plant = getPlantByIdReadOnly(userId, plantId);

        // Force initialization of lazy fields
        if (plant.room != null) {
            Hibernate.initialize(plant.room); // Force load
        }
        if (plant.species != null) {
            Hibernate.initialize(plant.species); // Force load
        }
        // Force load care logs to avoid LazyInitializationException
        if (plant.careLogs != null) {
            Hibernate.initialize(plant.careLogs); // Force load
        }

        boolean canManage = canManagePlant(userId, plant);
        return PlantDetailDTO.from(plant, canManage);
    }

    /**
     * Update a plant.
     */
    @Transactional
    public UserPlantEntity updatePlant(UUID userId, UUID plantId, UpdatePlantDTO dto) {
        UserPlantEntity plant = getPlantById(userId, plantId);

        if (dto.nickname() != null) {
            plant.nickname = dto.nickname();
        }
        if (dto.notes() != null) {
            plant.notes = dto.notes();
        }
        if (dto.photoPath() != null) {
            plant.photoPath = dto.photoPath();
        }
        if (dto.wateringIntervalDays() != null) {
            plant.wateringIntervalDays = dto.wateringIntervalDays();
        }
        if (dto.healthStatus() != null) {
            // Deprecated: healthStatus handled via booleans now
            // plant.healthStatus = dto.healthStatus();
        }
        if (dto.exposure() != null) {
            plant.exposure = dto.exposure();
        }
        if (dto.isSick() != null) {
            plant.isSick = dto.isSick();
        }
        if (dto.isWilted() != null) {
            plant.isWilted = dto.isWilted();
        }
        if (dto.needsRepotting() != null) {
            plant.needsRepotting = dto.needsRepotting();
        }
        if (dto.potDiameterCm() != null) {
            plant.potDiameterCm = dto.potDiameterCm();
        }

        // Handle room change
        if (dto.roomId() != null) {
            RoomEntity room = RoomEntity.findById(dto.roomId());
            if (room == null) {
                throw new NotFoundException("Room not found");
            }
            // Verify room belongs to user's active house
            UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
            UserEntity user = UserEntity.findById(userId);
            UUID activeHouseId = membership != null ? membership.house.id : (user != null && user.house != null ? user.house.id : null);
            if (activeHouseId == null || !room.house.id.equals(activeHouseId)) {
                throw new ForbiddenException("Room does not belong to your active house");
            }
            plant.room = room;
        }

        // Handle watering action
        if (dto.markAsWatered() != null && dto.markAsWatered()) {
            waterPlant(userId, plantId);
        }

        // Initialize lazy relationships to avoid LazyInitializationException in ResourceDTO
        if (plant.room != null) {
            Hibernate.initialize(plant.room);
        }
        if (plant.species != null) {
            Hibernate.initialize(plant.species);
        }

        return plant;
    }

    /**
     * Mark a plant as watered and create a care log.
     * The plant.water() method automatically:
     * - Updates lastWatered to now
     * - Sets healthStatus to GOOD
     * - Recalculates nextWateringDate
     */
    @Transactional
    public UserPlantEntity waterPlant(UUID userId, UUID plantId) {
        UserPlantEntity plant = getPlantById(userId, plantId);
        UserEntity user = UserEntity.findById(userId);

        // Use the entity's water() method which handles all updates
        plant.water();

        // Gamification: XP for watering
        gamificationService.onPlantWatered(userId, plant);

        // Create care log entry
        CareLogEntity careLog = new CareLogEntity();
        careLog.plant = plant;
        careLog.user = user;
        careLog.action = CareAction.WATERING;
        careLog.performedAt = OffsetDateTime.now();
        careLog.persist();

        // Force initialization of lazy fields to avoid LazyInitializationException in
        // DTO
        if (plant.room != null) {
            Hibernate.initialize(plant.room); // Force load
        }
        if (plant.species != null) {
            Hibernate.initialize(plant.species); // Force load
        }

        // Send push notification to house members
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership != null) {
            String displayName = user != null ? user.displayName : "Quelqu'un";
            fcmService.sendToHouseMembers(
                    membership.house.id,
                    userId,
                    "Plante arrosee",
                    displayName + " a arrose " + plant.nickname,
                    Map.of("type", "PLANT_WATERED", "plantId", plantId.toString())
            );
        }

        return plant;
    }

    /**
     * Delete a plant.
     */
    @Transactional
    public void deletePlant(UUID userId, UUID plantId) {
        UserPlantEntity plant = getPlantById(userId, plantId);
        plant.delete();
    }

    /**
     * Get care logs for a plant with optional action filter.
     */
    public List<CareLogDTO> getCareLogs(UUID userId, UUID plantId, String action) {
        // Verify read access (owner, delegate, or housemate)
        getPlantByIdReadOnly(userId, plantId);

        List<CareLogEntity> logs;
        if (action != null && !action.isBlank()) {
            CareAction careAction = CareAction.valueOf(action.toUpperCase());
            logs = CareLogEntity.findByPlantAndAction(plantId, careAction);
        } else {
            logs = CareLogEntity.findByPlant(plantId);
        }

        return logs.stream().map(CareLogDTO::from).toList();
    }

    /**
     * Create a care log entry (fertilization, repotting, pruning, treatment, note).
     */
    @Transactional
    public CareLogDTO createCareLog(UUID userId, UUID plantId, CreateCareLogDTO dto) {
        UserPlantEntity plant = getPlantById(userId, plantId);
        UserEntity user = UserEntity.findById(userId);

        CareLogEntity log = new CareLogEntity();
        log.plant = plant;
        log.user = user;
        log.action = dto.action();
        log.notes = dto.notes();
        log.performedAt = OffsetDateTime.now();
        log.persist();

        // Gamification: XP for care action (no XP for notes/watering)
        gamificationService.onCareAction(userId, plantId, dto.action());

        // Force load lazy fields for DTO
        Hibernate.initialize(log.plant);
        Hibernate.initialize(log.user);

        // Send push notification to house members
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership != null) {
            String displayName = user != null ? user.displayName : "Quelqu'un";
            String actionLabel = switch (dto.action()) {
                case WATERING -> "a arrose";
                case FERTILIZING -> "a fertilise";
                case REPOTTING -> "a rempote";
                case PRUNING -> "a taille";
                case TREATMENT -> "a traite";
                case NOTE -> "a ajoute une note sur";
            };
            fcmService.sendToHouseMembers(
                    membership.house.id,
                    userId,
                    "Soin enregistre",
                    displayName + " " + actionLabel + " " + plant.nickname,
                    Map.of("type", "CARE_LOG_ADDED",
                            "plantId", plantId.toString(),
                            "action", dto.action().name()));
        }

        return CareLogDTO.from(log);
    }

    /**
     * Delete a note-type care log for a plant.
     */
    @Transactional
    public void deleteCareLog(UUID userId, UUID plantId, UUID logId) {
        UserPlantEntity plant = getPlantById(userId, plantId);
        CareLogEntity log = CareLogEntity.findById(logId);

        if (log == null || log.plant == null || !log.plant.id.equals(plant.id)) {
            throw new NotFoundException("Care log not found");
        }
        if (log.action != CareAction.NOTE) {
            throw new ForbiddenException("Only note care logs can be deleted");
        }

        log.delete();
    }
}
