package com.plantmanager.service;

import com.plantmanager.dto.*;
import com.plantmanager.entity.*;
import com.plantmanager.entity.enums.CultureStatus;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;

import org.hibernate.Hibernate;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class GardenCultureService {

    @Inject
    FcmService fcmService;

    @Transactional
    public GardenCultureDTO createCulture(UUID userId, UUID houseId, CreateGardenCultureDTO dto) {
        UserEntity user = UserEntity.findById(userId);
        if (user == null) throw new NotFoundException("User not found");

        HouseEntity house = HouseEntity.findById(houseId);
        if (house == null) throw new NotFoundException("House not found");

        verifyMembership(userId, houseId);

        GardenCultureEntity culture = new GardenCultureEntity();
        culture.house = house;
        culture.createdBy = user;
        culture.plantName = dto.plantName();
        culture.variety = dto.variety();
        culture.sowDate = dto.sowDate() != null ? dto.sowDate() : LocalDate.now();
        culture.expectedHarvestDate = dto.expectedHarvestDate();
        culture.notes = dto.notes();
        culture.rowNumber = dto.rowNumber();
        culture.columnNumber = dto.columnNumber();
        culture.status = CultureStatus.SEMIS;
        culture.persist();

        return GardenCultureDTO.from(culture);
    }

    public List<GardenCultureDTO> getCulturesByHouse(UUID userId, UUID houseId, String statusFilter) {
        verifyMembership(userId, houseId);

        List<GardenCultureEntity> cultures;
        if (statusFilter != null && !statusFilter.isBlank()) {
            CultureStatus status = CultureStatus.valueOf(statusFilter.toUpperCase());
            cultures = GardenCultureEntity.findByStatus(houseId, status);
        } else {
            cultures = GardenCultureEntity.findByHouse(houseId);
        }

        return cultures.stream().map(c -> {
            Hibernate.initialize(c.createdBy); // force load
            List<GrowthLogDTO> logs = CultureGrowthLogEntity.findByCulture(c.id)
                    .stream().map(GrowthLogDTO::from).toList();
            return GardenCultureDTO.from(c, logs);
        }).toList();
    }

    public GardenCultureDTO getCultureById(UUID userId, UUID cultureId) {
        GardenCultureEntity culture = GardenCultureEntity.findById(cultureId);
        if (culture == null) throw new NotFoundException("Culture not found");

        verifyMembership(userId, culture.house.id);
        Hibernate.initialize(culture.createdBy);

        List<GrowthLogDTO> logs = CultureGrowthLogEntity.findByCulture(cultureId)
                .stream().map(GrowthLogDTO::from).toList();
        return GardenCultureDTO.from(culture, logs);
    }

    @Transactional
    public GardenCultureDTO updateStatus(UUID userId, UUID cultureId, UpdateCultureStatusDTO dto) {
        GardenCultureEntity culture = GardenCultureEntity.findById(cultureId);
        if (culture == null) throw new NotFoundException("Culture not found");

        verifyMembership(userId, culture.house.id);

        UserEntity user = UserEntity.findById(userId);

        // Create growth log
        CultureGrowthLogEntity log = new CultureGrowthLogEntity();
        log.culture = culture;
        log.user = user;
        log.oldStatus = culture.status;
        log.newStatus = dto.newStatus();
        log.heightCm = dto.heightCm();
        log.notes = dto.notes();
        log.persist();

        // Update culture
        culture.status = dto.newStatus();
        if (dto.newStatus() == CultureStatus.RECOLTE || dto.newStatus() == CultureStatus.TERMINE) {
            if (culture.actualHarvestDate == null) {
                culture.actualHarvestDate = LocalDate.now();
            }
            if (dto.harvestQuantity() != null) {
                culture.harvestQuantity = dto.harvestQuantity();
            }
        }

        Hibernate.initialize(culture.createdBy);
        List<GrowthLogDTO> logs = CultureGrowthLogEntity.findByCulture(cultureId)
                .stream().map(GrowthLogDTO::from).toList();
        return GardenCultureDTO.from(culture, logs);
    }

    @Transactional
    public void deleteCulture(UUID userId, UUID cultureId) {
        GardenCultureEntity culture = GardenCultureEntity.findById(cultureId);
        if (culture == null) throw new NotFoundException("Culture not found");

        verifyMembership(userId, culture.house.id);
        culture.delete();
    }

    private void verifyMembership(UUID userId, UUID houseId) {
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }
    }
}
