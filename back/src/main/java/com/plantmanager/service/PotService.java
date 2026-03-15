package com.plantmanager.service;

import com.plantmanager.dto.CreatePotStockDTO;
import com.plantmanager.dto.PotStockDTO;
import com.plantmanager.dto.RepotDTO;
import com.plantmanager.entity.*;
import com.plantmanager.entity.enums.CareAction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;

import org.hibernate.Hibernate;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Service for pot stock management and repotting logic.
 */
@ApplicationScoped
public class PotService {

    @Inject
    GamificationService gamificationService;

    /**
     * Get the active house ID for a user.
     */
    private UUID getActiveHouseId(UUID userId) {
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership == null) {
            UserEntity user = UserEntity.findById(userId);
            if (user != null && user.house != null) {
                return user.house.id;
            }
            throw new NotFoundException("Aucune maison active trouvee");
        }
        return membership.house.id;
    }

    /**
     * Get all pot stock for the user's active house.
     */
    public List<PotStockDTO> getPotStock(UUID userId) {
        UUID houseId = getActiveHouseId(userId);
        return PotStockEntity.findByHouse(houseId).stream()
                .map(PotStockDTO::from)
                .toList();
    }

    /**
     * Get available pots (quantity > 0) for the user's active house.
     */
    public List<PotStockDTO> getAvailablePots(UUID userId) {
        UUID houseId = getActiveHouseId(userId);
        return PotStockEntity.findAvailableByHouse(houseId).stream()
                .map(PotStockDTO::from)
                .toList();
    }

    /**
     * Add pots to stock. If a pot with the same diameter already exists, increment quantity.
     */
    @Transactional
    public PotStockDTO addToStock(UUID userId, CreatePotStockDTO dto) {
        UUID houseId = getActiveHouseId(userId);
        HouseEntity house = HouseEntity.findById(houseId);

        Optional<PotStockEntity> existing = PotStockEntity.findByHouseAndDiameter(houseId, dto.diameterCm());
        if (existing.isPresent()) {
            PotStockEntity pot = existing.get();
            pot.quantity += dto.quantity();
            if (dto.label() != null && !dto.label().isBlank()) {
                pot.label = dto.label();
            }
            return PotStockDTO.from(pot);
        }

        PotStockEntity pot = new PotStockEntity();
        pot.house = house;
        pot.diameterCm = dto.diameterCm();
        pot.quantity = dto.quantity();
        pot.label = dto.label();
        pot.persist();

        return PotStockDTO.from(pot);
    }

    /**
     * Update pot stock quantity.
     */
    @Transactional
    public PotStockDTO updateStock(UUID userId, UUID potId, int quantity) {
        UUID houseId = getActiveHouseId(userId);
        PotStockEntity pot = PotStockEntity.findById(potId);
        if (pot == null || !pot.house.id.equals(houseId)) {
            throw new NotFoundException("Pot non trouve");
        }

        if (quantity < 0) {
            throw new BadRequestException("La quantite ne peut pas etre negative");
        }

        pot.quantity = quantity;
        return PotStockDTO.from(pot);
    }

    /**
     * Delete a pot stock entry.
     */
    @Transactional
    public void deleteStock(UUID userId, UUID potId) {
        UUID houseId = getActiveHouseId(userId);
        PotStockEntity pot = PotStockEntity.findById(potId);
        if (pot == null || !pot.house.id.equals(houseId)) {
            throw new NotFoundException("Pot non trouve");
        }
        pot.delete();
    }

    /**
     * Repot a plant:
     * 1. Take the new pot from stock (decrement quantity)
     * 2. Return the old pot to stock (increment quantity or create entry)
     * 3. Update plant's pot_diameter_cm
     * 4. Set needsRepotting = false
     * 5. Create a REPOTTING care log
     */
    @Transactional
    public UserPlantEntity repotPlant(UUID userId, UUID plantId, RepotDTO dto) {
        UserPlantEntity plant = UserPlantEntity.findById(plantId);
        if (plant == null) {
            throw new NotFoundException("Plante non trouvee");
        }
        if (!plant.user.id.equals(userId)) {
            throw new ForbiddenException("Cette plante ne vous appartient pas");
        }

        UUID houseId = getActiveHouseId(userId);
        HouseEntity house = HouseEntity.findById(houseId);

        // 1. Take new pot from stock
        Optional<PotStockEntity> newPotOpt = PotStockEntity.findByHouseAndDiameter(houseId, dto.newDiameterCm());
        if (newPotOpt.isEmpty() || newPotOpt.get().quantity <= 0) {
            throw new BadRequestException("Aucun pot de " + dto.newDiameterCm() + " cm disponible en stock");
        }
        PotStockEntity newPot = newPotOpt.get();
        newPot.quantity--;

        // 2. Return old pot to stock (if plant had a pot)
        if (plant.potDiameterCm != null) {
            Optional<PotStockEntity> oldPotOpt = PotStockEntity.findByHouseAndDiameter(houseId, plant.potDiameterCm);
            if (oldPotOpt.isPresent()) {
                oldPotOpt.get().quantity++;
            } else {
                PotStockEntity oldPot = new PotStockEntity();
                oldPot.house = house;
                oldPot.diameterCm = plant.potDiameterCm;
                oldPot.quantity = 1;
                oldPot.persist();
            }
        }

        // 3. Update plant
        BigDecimal oldDiameter = plant.potDiameterCm;
        plant.potDiameterCm = dto.newDiameterCm();
        plant.needsRepotting = false;

        // 4. Create care log
        UserEntity user = UserEntity.findById(userId);
        CareLogEntity careLog = new CareLogEntity();
        careLog.plant = plant;
        careLog.user = user;
        careLog.action = CareAction.REPOTTING;
        careLog.notes = buildRepotNotes(oldDiameter, dto.newDiameterCm(), dto.notes());
        careLog.performedAt = OffsetDateTime.now();
        careLog.persist();

        // 5. Gamification
        gamificationService.onCareAction(userId, plantId, CareAction.REPOTTING);

        // Force load lazy fields
        if (plant.room != null) {
            Hibernate.initialize(plant.room);
        }
        if (plant.species != null) {
            Hibernate.initialize(plant.species);
        }

        return plant;
    }

    /**
     * Get pots that could be used for repotting a specific plant (larger than current).
     */
    public List<PotStockDTO> getSuggestedPots(UUID userId, UUID plantId) {
        UserPlantEntity plant = UserPlantEntity.findById(plantId);
        if (plant == null) {
            throw new NotFoundException("Plante non trouvee");
        }

        UUID houseId = getActiveHouseId(userId);
        BigDecimal currentDiameter = plant.potDiameterCm != null ? plant.potDiameterCm : BigDecimal.ZERO;

        return PotStockEntity.findLargerPots(houseId, currentDiameter).stream()
                .map(PotStockDTO::from)
                .toList();
    }

    private String buildRepotNotes(BigDecimal oldDiameter, BigDecimal newDiameter, String userNotes) {
        StringBuilder sb = new StringBuilder();
        if (oldDiameter != null) {
            sb.append("Rempotage de ").append(oldDiameter).append(" cm vers ").append(newDiameter).append(" cm.");
        } else {
            sb.append("Premier rempotage: pot de ").append(newDiameter).append(" cm.");
        }
        if (userNotes != null && !userNotes.isBlank()) {
            sb.append(" ").append(userNotes);
        }
        return sb.toString();
    }
}
