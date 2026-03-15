package com.plantmanager.service;

import com.plantmanager.dto.VacationRequestDTO;
import com.plantmanager.dto.VacationResponseDTO;
import com.plantmanager.entity.HouseEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserHouseEntity;
import com.plantmanager.entity.VacationDelegationEntity;
import com.plantmanager.entity.enums.VacationStatus;
import org.hibernate.Hibernate;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import org.jboss.logging.Logger;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Service for vacation mode / temporary delegation.
 * Allows users to delegate plant care to another house member while on vacation.
 */
@ApplicationScoped
public class VacationService {

    private static final Logger LOG = Logger.getLogger(VacationService.class);

    @Inject
    FcmService fcmService;

    @Inject
    GamificationService gamificationService;

    /**
     * Activate vacation mode: delegate plant care to another house member.
     */
    @Transactional
    public VacationResponseDTO activateVacation(UUID userId, UUID houseId, VacationRequestDTO dto) {
        // Verify membership
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        // Verify delegate is also a member
        UserHouseEntity delegateMembership = UserHouseEntity.findByUserAndHouse(dto.delegateId(), houseId);
        if (delegateMembership == null) {
            throw new BadRequestException("Delegate is not a member of this house");
        }

        // Cannot delegate to yourself
        if (userId.equals(dto.delegateId())) {
            throw new BadRequestException("Cannot delegate to yourself");
        }

        // Validate dates
        if (dto.endDate().isBefore(dto.startDate())) {
            throw new BadRequestException("End date must be after start date");
        }

        if (dto.endDate().isBefore(LocalDate.now())) {
            throw new BadRequestException("End date must be today or in the future");
        }

        // Check if already on vacation in this house
        VacationDelegationEntity existing = VacationDelegationEntity.findActiveDelegationByDelegator(userId, houseId);
        if (existing != null) {
            throw new BadRequestException("You already have an active vacation delegation in this house. Cancel it first.");
        }

        // Check if delegate has an active delegation (on vacation or scheduled) - can't delegate to someone who's away
        VacationDelegationEntity delegateVacation = VacationDelegationEntity.findActiveDelegationByDelegator(dto.delegateId(), houseId);
        if (delegateVacation != null) {
            throw new BadRequestException("This member is currently on vacation and cannot accept delegations");
        }

        // Create delegation
        UserEntity delegator = UserEntity.findById(userId);
        UserEntity delegate = UserEntity.findById(dto.delegateId());
        HouseEntity house = HouseEntity.findById(houseId);

        VacationDelegationEntity delegation = new VacationDelegationEntity();
        delegation.house = house;
        delegation.delegator = delegator;
        delegation.delegate = delegate;
        delegation.startDate = dto.startDate();
        delegation.endDate = dto.endDate();
        delegation.status = VacationStatus.ACTIVE;
        delegation.message = dto.message();
        delegation.persist();

        // Gamification: GUARDIAN_ANGEL badge for the delegate
        gamificationService.onDelegationAccepted(dto.delegateId());

        // Notify the delegate
        fcmService.sendToUser(dto.delegateId(),
                "Mode vacances active",
                delegator.displayName + " vous a delegue le soin de ses plantes du "
                        + dto.startDate() + " au " + dto.endDate(),
                Map.of("type", "VACATION_DELEGATED",
                        "houseId", houseId.toString(),
                        "delegationId", delegation.id.toString()));

        LOG.infof("Vacation activated: %s delegated to %s in house %s (%s to %s)",
                delegator.displayName, delegate.displayName, house.name,
                dto.startDate(), dto.endDate());

        // Force load lazy fields for response
        Hibernate.initialize(delegation.delegator);
        Hibernate.initialize(delegation.delegate);

        return VacationResponseDTO.from(delegation);
    }

    /**
     * Cancel vacation mode (early return).
     */
    @Transactional
    public void cancelVacation(UUID userId, UUID houseId) {
        VacationDelegationEntity delegation = VacationDelegationEntity.findActiveDelegationByDelegator(userId, houseId);
        if (delegation == null) {
            throw new NotFoundException("No active vacation found for this house");
        }

        delegation.status = VacationStatus.CANCELLED;

        // Notify the delegate
        fcmService.sendToUser(delegation.delegate.id,
                "Mode vacances termine",
                delegation.delegator.displayName + " est de retour. La delegation est terminee.",
                Map.of("type", "VACATION_CANCELLED",
                        "houseId", houseId.toString()));

        LOG.infof("Vacation cancelled for user %s in house %s", userId, houseId);
    }

    /**
     * Get vacation status for a user in a house.
     */
    public VacationResponseDTO getVacationStatus(UUID userId, UUID houseId) {
        // Verify membership
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        VacationDelegationEntity delegation = VacationDelegationEntity.findActiveDelegationByDelegator(userId, houseId);
        if (delegation == null) {
            return null;
        }

        // Force load lazy fields
        Hibernate.initialize(delegation.delegator);
        Hibernate.initialize(delegation.delegate);

        return VacationResponseDTO.from(delegation);
    }

    /**
     * Get all active delegations in a house (visible to all members).
     */
    public List<VacationResponseDTO> getHouseDelegations(UUID userId, UUID houseId) {
        // Verify membership
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        List<VacationDelegationEntity> delegations = VacationDelegationEntity.findActiveByHouse(houseId);

        return delegations.stream()
                .peek(d -> {
                    Hibernate.initialize(d.delegator);
                    Hibernate.initialize(d.delegate);
                })
                .map(VacationResponseDTO::from)
                .toList();
    }

    /**
     * Get delegations where the user is the delegate (plants they need to care for).
     */
    public List<VacationResponseDTO> getMyDelegations(UUID userId, UUID houseId) {
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        List<VacationDelegationEntity> delegations = VacationDelegationEntity.findActiveDelegationsByDelegate(userId, houseId);

        return delegations.stream()
                .peek(d -> {
                    Hibernate.initialize(d.delegator);
                    Hibernate.initialize(d.delegate);
                })
                .map(VacationResponseDTO::from)
                .toList();
    }

    /**
     * Scheduled task: expire delegations whose end_date has passed.
     * Runs daily at 00:05 AM.
     */
    @Scheduled(cron = "0 5 0 * * ?")
    @Transactional
    public void expireVacations() {
        List<VacationDelegationEntity> expired = VacationDelegationEntity.findExpired();

        if (expired.isEmpty()) return;

        for (VacationDelegationEntity delegation : expired) {
            delegation.status = VacationStatus.EXPIRED;

            // Notify both delegator and delegate
            fcmService.sendToUser(delegation.delegator.id,
                    "Mode vacances termine",
                    "Votre mode vacances est termine. Vous recevez a nouveau les rappels d'arrosage.",
                    Map.of("type", "VACATION_EXPIRED", "houseId", delegation.house.id.toString()));

            fcmService.sendToUser(delegation.delegate.id,
                    "Delegation terminee",
                    "La delegation de " + delegation.delegator.displayName + " est terminee.",
                    Map.of("type", "VACATION_EXPIRED", "houseId", delegation.house.id.toString()));
        }

        LOG.infof("Expired %d vacation delegations", expired.size());
    }

    /**
     * Check if a user is on vacation (used by other services).
     */
    public boolean isUserOnVacation(UUID userId) {
        VacationDelegationEntity delegation = VacationDelegationEntity.findActiveDelegationByDelegator(userId);
        return delegation != null;
    }

    /**
     * Get the delegate for a user who is on vacation.
     * Returns null if user is not on vacation.
     */
    public UUID getDelegateForUser(UUID userId) {
        VacationDelegationEntity delegation = VacationDelegationEntity.findActiveDelegationByDelegator(userId);
        return delegation != null ? delegation.delegate.id : null;
    }

    /**
     * Get all user IDs whose plants this delegate is responsible for.
     */
    public List<UUID> getDelegatorIdsForDelegate(UUID delegateId) {
        List<VacationDelegationEntity> delegations = VacationDelegationEntity.findActiveDelegationsForDelegate(delegateId);
        return delegations.stream()
                .map(d -> d.delegator.id)
                .toList();
    }
}
