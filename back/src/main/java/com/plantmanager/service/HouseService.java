package com.plantmanager.service;

import com.plantmanager.dto.CreateHouseDTO;
import com.plantmanager.dto.HouseInvitationDTO;
import com.plantmanager.dto.HouseMemberDTO;
import com.plantmanager.dto.HouseResponseDTO;
import com.plantmanager.dto.JoinHouseDTO;
import com.plantmanager.entity.HouseEntity;
import com.plantmanager.entity.HouseInvitationEntity;
import com.plantmanager.entity.RoomEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserHouseEntity;
import com.plantmanager.entity.NotificationEntity;
import com.plantmanager.entity.enums.InvitationStatus;
import com.plantmanager.entity.enums.NotificationType;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.entity.CareLogEntity;

import jakarta.inject.Inject;

import org.hibernate.Hibernate;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Service for house business logic.
 */
@ApplicationScoped
public class HouseService {

    @Inject
    FcmService fcmService;

    @Inject
    GamificationService gamificationService;

    /**
     * Get all houses for a user.
     */
    public List<HouseResponseDTO> getUserHouses(UUID userId) {
        List<UserHouseEntity> memberships = UserHouseEntity.findByUser(userId);
        return memberships.stream()
                .map(m -> HouseResponseDTO.from(m.house, m))
                .toList();
    }

    /**
     * Get the active house for a user.
     */
    public HouseResponseDTO getActiveHouse(UUID userId) {
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership == null) {
            throw new NotFoundException("No active house found");
        }
        return HouseResponseDTO.from(membership.house, membership);
    }

    /**
     * Get a house by ID (with membership check).
     */
    public HouseResponseDTO getHouseById(UUID userId, UUID houseId) {
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }
        return HouseResponseDTO.from(membership.house, membership);
    }

    /**
     * Create a new house (user becomes OWNER).
     */
    @Transactional
    public HouseResponseDTO createHouse(UUID userId, CreateHouseDTO dto) {
        UserEntity user = UserEntity.findById(userId);
        if (user == null) {
            throw new NotFoundException("User not found");
        }

        // Create the house
        HouseEntity house = new HouseEntity();
        house.name = dto.name();
        house.persist();

        // Create membership (as OWNER and active)
        UserHouseEntity membership = new UserHouseEntity();
        membership.user = user;
        membership.house = house;
        membership.role = UserEntity.UserRole.OWNER;
        membership.isActive = true;
        membership.persist();

        // Deactivate other houses for this user
        deactivateOtherHouses(userId, house.id);

        return HouseResponseDTO.from(house, membership);
    }

    /**
     * Request to join a house using invite code.
     * Creates a PENDING invitation that must be accepted by an owner.
     */
    @Transactional
    public HouseInvitationDTO requestJoinHouse(UUID userId, JoinHouseDTO dto) {
        UserEntity user = UserEntity.findById(userId);
        if (user == null) {
            throw new NotFoundException("User not found");
        }

        HouseEntity house = HouseEntity.findByInviteCode(dto.inviteCode())
                .orElseThrow(() -> new NotFoundException("Invalid invite code"));

        // Check if already a member
        UserHouseEntity existing = UserHouseEntity.findByUserAndHouse(userId, house.id);
        if (existing != null) {
            throw new BadRequestException("Vous etes deja membre de cette maison");
        }

        // Check if already has a pending request
        HouseInvitationEntity existingInvitation = HouseInvitationEntity.findPendingByRequesterAndHouse(userId, house.id);
        if (existingInvitation != null) {
            throw new BadRequestException("Vous avez deja une demande en attente pour cette maison");
        }

        // Create pending invitation
        HouseInvitationEntity invitation = new HouseInvitationEntity();
        invitation.house = house;
        invitation.requester = user;
        invitation.status = InvitationStatus.PENDING;
        invitation.persist();

        // Send notification to all owners of the house
        List<UserHouseEntity> owners = UserHouseEntity.list("house.id = ?1 and role = ?2",
                house.id, UserEntity.UserRole.OWNER);
        for (UserHouseEntity owner : owners) {
            NotificationEntity notification = new NotificationEntity();
            notification.user = owner.user;
            notification.type = NotificationType.HOUSE_INVITATION;
            notification.message = user.displayName + " souhaite rejoindre votre maison \"" + house.name + "\"";
            notification.invitation = invitation;
            notification.house = house;
            notification.persist();
        }

        // Send push notification to owners
        fcmService.sendToHouseMembers(
                house.id,
                userId,
                "Demande d'adhesion",
                user.displayName + " souhaite rejoindre votre maison",
                Map.of("type", "HOUSE_INVITATION", "houseId", house.id.toString(), "invitationId", invitation.id.toString())
        );

        return HouseInvitationDTO.from(invitation);
    }

    /**
     * Accept a join request (OWNER only).
     */
    @Transactional
    public HouseInvitationDTO acceptInvitation(UUID ownerId, UUID invitationId) {
        HouseInvitationEntity invitation = HouseInvitationEntity.findById(invitationId);
        if (invitation == null) {
            throw new NotFoundException("Demande introuvable");
        }

        // Verify the responder is an OWNER of the house
        UserHouseEntity ownerMembership = UserHouseEntity.findByUserAndHouse(ownerId, invitation.house.id);
        if (ownerMembership == null || ownerMembership.role != UserEntity.UserRole.OWNER) {
            throw new ForbiddenException("Seul le proprietaire peut accepter les demandes");
        }

        if (invitation.status != InvitationStatus.PENDING) {
            throw new BadRequestException("Cette demande a deja ete traitee");
        }

        UserEntity owner = UserEntity.findById(ownerId);

        // Accept the invitation
        invitation.status = InvitationStatus.ACCEPTED;
        invitation.respondedBy = owner;
        invitation.respondedAt = OffsetDateTime.now();

        // Create membership for the requester
        UserHouseEntity membership = new UserHouseEntity();
        membership.user = invitation.requester;
        membership.house = invitation.house;
        membership.role = UserEntity.UserRole.MEMBER;
        membership.isActive = true;
        membership.persist();

        // Deactivate other houses for the new member
        deactivateOtherHouses(invitation.requester.id, invitation.house.id);

        // Gamification
        gamificationService.onHouseJoined(invitation.requester.id, invitation.house.id);

        // Notify the requester that they were accepted
        NotificationEntity notification = new NotificationEntity();
        notification.user = invitation.requester;
        notification.type = NotificationType.MEMBER_JOINED;
        notification.message = "Votre demande pour rejoindre \"" + invitation.house.name + "\" a ete acceptee !";
        notification.house = invitation.house;
        notification.persist();

        // Push notification to the requester
        fcmService.sendToUser(
                invitation.requester.id,
                "Demande acceptee",
                "Vous avez rejoint la maison \"" + invitation.house.name + "\"",
                Map.of("type", "MEMBER_JOINED", "houseId", invitation.house.id.toString())
        );

        // Notify existing members
        fcmService.sendToHouseMembers(
                invitation.house.id,
                invitation.requester.id,
                "Nouveau membre",
                invitation.requester.displayName + " a rejoint la maison",
                Map.of("type", "MEMBER_JOINED", "houseId", invitation.house.id.toString())
        );

        return HouseInvitationDTO.from(invitation);
    }

    /**
     * Decline a join request (OWNER only).
     */
    @Transactional
    public HouseInvitationDTO declineInvitation(UUID ownerId, UUID invitationId) {
        HouseInvitationEntity invitation = HouseInvitationEntity.findById(invitationId);
        if (invitation == null) {
            throw new NotFoundException("Demande introuvable");
        }

        // Verify the responder is an OWNER of the house
        UserHouseEntity ownerMembership = UserHouseEntity.findByUserAndHouse(ownerId, invitation.house.id);
        if (ownerMembership == null || ownerMembership.role != UserEntity.UserRole.OWNER) {
            throw new ForbiddenException("Seul le proprietaire peut refuser les demandes");
        }

        if (invitation.status != InvitationStatus.PENDING) {
            throw new BadRequestException("Cette demande a deja ete traitee");
        }

        UserEntity owner = UserEntity.findById(ownerId);

        // Decline the invitation
        invitation.status = InvitationStatus.DECLINED;
        invitation.respondedBy = owner;
        invitation.respondedAt = OffsetDateTime.now();

        // Notify the requester
        NotificationEntity notification = new NotificationEntity();
        notification.user = invitation.requester;
        notification.type = NotificationType.HOUSE_INVITATION;
        notification.message = "Votre demande pour rejoindre \"" + invitation.house.name + "\" a ete refusee.";
        notification.house = invitation.house;
        notification.persist();

        // Push notification to the requester
        fcmService.sendToUser(
                invitation.requester.id,
                "Demande refusee",
                "Votre demande pour \"" + invitation.house.name + "\" a ete refusee",
                Map.of("type", "HOUSE_INVITATION", "houseId", invitation.house.id.toString())
        );

        return HouseInvitationDTO.from(invitation);
    }

    /**
     * Get pending invitations for a house (OWNER only).
     */
    public List<HouseInvitationDTO> getPendingInvitations(UUID ownerId, UUID houseId) {
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(ownerId, houseId);
        if (membership == null || membership.role != UserEntity.UserRole.OWNER) {
            throw new ForbiddenException("Seul le proprietaire peut voir les demandes");
        }

        List<HouseInvitationEntity> invitations = HouseInvitationEntity.findPendingByHouse(houseId);
        return invitations.stream()
                .map(HouseInvitationDTO::from)
                .toList();
    }

    /**
     * Get my pending join requests (as requester).
     */
    public List<HouseInvitationDTO> getMyPendingRequests(UUID userId) {
        List<HouseInvitationEntity> invitations = HouseInvitationEntity.findPendingByRequester(userId);
        return invitations.stream()
                .map(HouseInvitationDTO::from)
                .toList();
    }

    /**
     * Switch active house.
     */
    @Transactional
    public HouseResponseDTO switchActiveHouse(UUID userId, UUID houseId) {
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        // Deactivate all other houses
        deactivateOtherHouses(userId, houseId);

        // Activate this house
        membership.isActive = true;

        return HouseResponseDTO.from(membership.house, membership);
    }

    /**
     * Leave a house.
     */
    @Transactional
    public void leaveHouse(UUID userId, UUID houseId) {
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        // Can't leave if you're the only OWNER
        if (membership.role == UserEntity.UserRole.OWNER) {
            long ownerCount = UserHouseEntity.count("house.id = ?1 and role = ?2",
                    houseId, UserEntity.UserRole.OWNER);
            if (ownerCount <= 1) {
                throw new BadRequestException("Cannot leave: you are the only owner. Transfer ownership first.");
            }
        }

        boolean wasActive = membership.isActive;
        membership.delete();

        // If this was the active house, activate another one
        if (wasActive) {
            List<UserHouseEntity> remaining = UserHouseEntity.findByUser(userId);
            if (!remaining.isEmpty()) {
                remaining.get(0).isActive = true;
            }
        }
    }

    /**
     * Delete a house (Owner only).
     */
    @Transactional
    public void deleteHouse(UUID userId, UUID houseId) {
        // Fetch the house (managed entity)
        HouseEntity house = HouseEntity.findById(houseId);
        if (house == null) {
            throw new NotFoundException("House not found");
        }

        // Verify membership and ownership
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        if (membership.role != UserEntity.UserRole.OWNER) {
            throw new ForbiddenException("Only the owner can delete the house");
        }

        // 1. Manually delete all rooms (and their plants/children)
        // We iterate specifically to trigger cascades and avoid "TransientPropertyValueException"
        List<RoomEntity> rooms = RoomEntity.findByHouse(houseId);
        for (RoomEntity room : rooms) {
            // Delete plants in this room
            List<UserPlantEntity> plants = UserPlantEntity.findByRoom(room.id);
            for (UserPlantEntity plant : plants) {
                // This deletes logs and notifications via cascade if configured,
                // otherwise we might need to delete them explicitly too.
                // Given previous errors, let's be safe:
                CareLogEntity.delete("plant.id = ?1", plant.id);
                NotificationEntity.delete("plant.id = ?1", plant.id);
                plant.delete();
            }
            room.delete();
        }
        
        // 2. Delete all memberships manually
        List<UserHouseEntity> members = UserHouseEntity.list("house.id", houseId);
        for (UserHouseEntity m : members) {
            m.delete();
        }

        // 3. Finally delete the house
        house.delete();
    }

    // ==================== MEMBER MANAGEMENT ====================

    /**
     * Get all members of a house (must be a member to view).
     */
    public List<HouseMemberDTO> getHouseMembers(UUID userId, UUID houseId) {
        // Verify requester is a member
        UserHouseEntity requesterMembership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (requesterMembership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        List<UserHouseEntity> members = UserHouseEntity.findByHouse(houseId);
        return members.stream()
                .map(HouseMemberDTO::from)
                .toList();
    }

    /**
     * Update a member's role (OWNER only).
     * Can promote MEMBER to OWNER or demote OWNER to MEMBER.
     */
    @Transactional
    public HouseMemberDTO updateMemberRole(UUID requesterId, UUID houseId, UUID targetUserId, String newRole) {
        // Verify requester is OWNER
        UserHouseEntity requesterMembership = UserHouseEntity.findByUserAndHouse(requesterId, houseId);
        if (requesterMembership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }
        if (requesterMembership.role != UserEntity.UserRole.OWNER) {
            throw new ForbiddenException("Only owners can change member roles");
        }

        // Find target member
        UserHouseEntity targetMembership = UserHouseEntity.findByUserAndHouse(targetUserId, houseId);
        if (targetMembership == null) {
            throw new NotFoundException("Member not found in this house");
        }

        // Parse and validate new role
        UserEntity.UserRole role;
        try {
            role = UserEntity.UserRole.valueOf(newRole.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("Invalid role. Must be OWNER, MEMBER or GUEST");
        }

        // Prevent demoting yourself if you're the only OWNER
        if (requesterId.equals(targetUserId) && role != UserEntity.UserRole.OWNER) {
            long ownerCount = UserHouseEntity.count("house.id = ?1 and role = ?2",
                    houseId, UserEntity.UserRole.OWNER);
            if (ownerCount <= 1) {
                throw new BadRequestException("Cannot demote: you are the only owner. Promote another member first.");
            }
        }

        // Update role
        targetMembership.role = role;

        return HouseMemberDTO.from(targetMembership);
    }

    /**
     * Remove a member from a house (OWNER only).
     * Cannot remove yourself (use leaveHouse instead).
     */
    @Transactional
    public void removeMember(UUID requesterId, UUID houseId, UUID targetUserId) {
        // Can't kick yourself
        if (requesterId.equals(targetUserId)) {
            throw new BadRequestException("Cannot remove yourself. Use leave house instead.");
        }

        // Verify requester is OWNER
        UserHouseEntity requesterMembership = UserHouseEntity.findByUserAndHouse(requesterId, houseId);
        if (requesterMembership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }
        if (requesterMembership.role != UserEntity.UserRole.OWNER) {
            throw new ForbiddenException("Only owners can remove members");
        }

        // Find target member
        UserHouseEntity targetMembership = UserHouseEntity.findByUserAndHouse(targetUserId, houseId);
        if (targetMembership == null) {
            throw new NotFoundException("Member not found in this house");
        }

        // Delete membership
        targetMembership.delete();

        // If target had this as active house, activate another one for them
        List<UserHouseEntity> remaining = UserHouseEntity.findByUser(targetUserId);
        if (!remaining.isEmpty() && remaining.stream().noneMatch(m -> m.isActive)) {
            remaining.get(0).isActive = true;
        }
    }

    /**
     * Helper to deactivate all houses for a user except one.
     */
    private void deactivateOtherHouses(UUID userId, UUID exceptHouseId) {
        UserHouseEntity.update("isActive = false where user.id = ?1 and house.id != ?2",
                userId, exceptHouseId);
    }

    /**
     * Get house-wide activity feed: recent care logs from all members.
     */
    public List<com.plantmanager.dto.CareLogDTO> getHouseActivity(UUID userId, UUID houseId, int limit) {
        // Verify membership
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }

        List<CareLogEntity> logs = CareLogEntity.findByHouse(houseId, limit);

        // Force load lazy fields
        return logs.stream()
                .peek(log -> {
                    if (log.plant != null) Hibernate.initialize(log.plant);
                    if (log.user != null) Hibernate.initialize(log.user);
                })
                .map(com.plantmanager.dto.CareLogDTO::from)
                .toList();
    }
}
