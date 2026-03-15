package com.plantmanager.resource;

import com.plantmanager.dto.CreateHouseDTO;
import com.plantmanager.dto.HouseMemberDTO;
import com.plantmanager.dto.HouseResponseDTO;
import com.plantmanager.dto.JoinHouseDTO;
import com.plantmanager.dto.UpdateMemberRoleDTO;
import com.plantmanager.dto.CareLogDTO;
import com.plantmanager.dto.VacationRequestDTO;
import com.plantmanager.dto.VacationResponseDTO;
import com.plantmanager.service.HouseService;
import com.plantmanager.service.VacationService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.List;
import java.util.UUID;

/**
 * REST Resource for house management.
 * Allows users to create, join, switch, and manage houses.
 */
@Path("/houses")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "House", description = "Gestion des maisons")
@RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
public class HouseResource {

    @Inject
    HouseService houseService;

    @Inject
    VacationService vacationService;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    // ==================== LIST MY HOUSES ====================

    @GET
    @Operation(summary = "Lister mes maisons", description = "Retourne toutes les maisons dont l'utilisateur est membre")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Liste des maisons", content = @Content(schema = @Schema(implementation = HouseResponseDTO[].class)))
    })
    public Response getMyHouses() {
        List<HouseResponseDTO> houses = houseService.getUserHouses(getCurrentUserId());
        return Response.ok(houses).build();
    }

    // ==================== GET ACTIVE HOUSE ====================

    @GET
    @Path("/active")
    @Operation(summary = "Maison active", description = "Retourne la maison actuellement sélectionnée")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Maison active", content = @Content(schema = @Schema(implementation = HouseResponseDTO.class))),
            @APIResponse(responseCode = "404", description = "Aucune maison active")
    })
    public Response getActiveHouse() {
        HouseResponseDTO house = houseService.getActiveHouse(getCurrentUserId());
        return Response.ok(house).build();
    }

    // ==================== GET HOUSE BY ID ====================

    @GET
    @Path("/{id}")
    @Operation(summary = "Détail d'une maison", description = "Retourne les informations d'une maison")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Détails de la maison", content = @Content(schema = @Schema(implementation = HouseResponseDTO.class))),
            @APIResponse(responseCode = "403", description = "Non membre de cette maison"),
            @APIResponse(responseCode = "404", description = "Maison non trouvée")
    })
    public Response getHouseById(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id) {
        HouseResponseDTO house = houseService.getHouseById(getCurrentUserId(), id);
        return Response.ok(house).build();
    }

    // ==================== CREATE HOUSE ====================

    @POST
    @Operation(summary = "Créer une maison", description = "Créer une nouvelle maison (l'utilisateur devient OWNER)")
    @APIResponses({
            @APIResponse(responseCode = "201", description = "Maison créée", content = @Content(schema = @Schema(implementation = HouseResponseDTO.class))),
            @APIResponse(responseCode = "400", description = "Données invalides")
    })
    public Response createHouse(@Valid CreateHouseDTO request) {
        HouseResponseDTO house = houseService.createHouse(getCurrentUserId(), request);
        return Response.status(Response.Status.CREATED).entity(house).build();
    }

    // ==================== JOIN HOUSE ====================

    @POST
    @Path("/join")
    @Operation(summary = "Rejoindre une maison", description = "Rejoindre une maison existante via code d'invitation")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Maison rejointe", content = @Content(schema = @Schema(implementation = HouseResponseDTO.class))),
            @APIResponse(responseCode = "400", description = "Déjà membre ou code invalide"),
            @APIResponse(responseCode = "404", description = "Code d'invitation invalide")
    })
    public Response joinHouse(@Valid JoinHouseDTO request) {
        HouseResponseDTO house = houseService.joinHouse(getCurrentUserId(), request);
        return Response.ok(house).build();
    }

    // ==================== SWITCH ACTIVE HOUSE ====================

    @PUT
    @Path("/{id}/activate")
    @Operation(summary = "Changer de maison active", description = "Sélectionner cette maison comme maison active")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Maison activée", content = @Content(schema = @Schema(implementation = HouseResponseDTO.class))),
            @APIResponse(responseCode = "403", description = "Non membre de cette maison")
    })
    public Response switchActiveHouse(
            @Parameter(description = "ID de la maison à activer", required = true) @PathParam("id") UUID id) {
        HouseResponseDTO house = houseService.switchActiveHouse(getCurrentUserId(), id);
        return Response.ok(house).build();
    }

    // ==================== LEAVE HOUSE ====================

    @DELETE
    @Path("/{id}/leave")
    @Operation(summary = "Quitter une maison", description = "Quitter une maison (impossible si seul OWNER)")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Maison quittée"),
            @APIResponse(responseCode = "400", description = "Impossible de quitter (seul owner)"),
            @APIResponse(responseCode = "403", description = "Non membre de cette maison")
    })
    public Response leaveHouse(
            @Parameter(description = "ID de la maison à quitter", required = true) @PathParam("id") UUID id) {
        houseService.leaveHouse(getCurrentUserId(), id);
        return Response.noContent().build();
    }

    // ==================== DELETE HOUSE ====================

    @DELETE
    @Path("/{id}")
    @Operation(summary = "Supprimer une maison", description = "Supprimer définitivement une maison et tout son contenu (Owner uniquement)")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Maison supprimée"),
            @APIResponse(responseCode = "403", description = "Non autorisé (pas owner)")
    })
    public Response deleteHouse(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id) {
        houseService.deleteHouse(getCurrentUserId(), id);
        return Response.noContent().build();
    }

    // ==================== MEMBER MANAGEMENT ====================

    @GET
    @Path("/{id}/members")
    @Operation(summary = "Lister les membres", description = "Retourne tous les membres d'une maison")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Liste des membres", content = @Content(schema = @Schema(implementation = HouseMemberDTO[].class))),
            @APIResponse(responseCode = "403", description = "Non membre de cette maison")
    })
    public Response getHouseMembers(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id) {
        List<HouseMemberDTO> members = houseService.getHouseMembers(getCurrentUserId(), id);
        return Response.ok(members).build();
    }

    @PUT
    @Path("/{houseId}/members/{userId}/role")
    @Operation(summary = "Changer le rôle d'un membre", description = "Promouvoir ou rétrograder un membre (Owner uniquement)")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Rôle modifié", content = @Content(schema = @Schema(implementation = HouseMemberDTO.class))),
            @APIResponse(responseCode = "400", description = "Rôle invalide ou action impossible"),
            @APIResponse(responseCode = "403", description = "Non autorisé (pas owner)"),
            @APIResponse(responseCode = "404", description = "Membre non trouvé")
    })
    public Response updateMemberRole(
            @Parameter(description = "ID de la maison", required = true) @PathParam("houseId") UUID houseId,
            @Parameter(description = "ID du membre", required = true) @PathParam("userId") UUID userId,
            @Valid UpdateMemberRoleDTO request) {
        HouseMemberDTO member = houseService.updateMemberRole(getCurrentUserId(), houseId, userId, request.role());
        return Response.ok(member).build();
    }

    @DELETE
    @Path("/{houseId}/members/{userId}")
    @Operation(summary = "Exclure un membre", description = "Retirer un membre de la maison (Owner uniquement)")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Membre exclu"),
            @APIResponse(responseCode = "400", description = "Action impossible (ex: s'exclure soi-même)"),
            @APIResponse(responseCode = "403", description = "Non autorisé (pas owner)"),
            @APIResponse(responseCode = "404", description = "Membre non trouvé")
    })
    public Response removeMember(
            @Parameter(description = "ID de la maison", required = true) @PathParam("houseId") UUID houseId,
            @Parameter(description = "ID du membre à exclure", required = true) @PathParam("userId") UUID userId) {
        houseService.removeMember(getCurrentUserId(), houseId, userId);
        return Response.noContent().build();
    }

    // ==================== ACTIVITY FEED ====================

    @GET
    @Path("/{id}/activity")
    @Operation(summary = "Fil d'activite", description = "Historique partage des actions dans la maison : qui a fait quoi et quand (arrosage, fertilisation, rempotage, etc.)")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Historique des activites",
                    content = @Content(schema = @Schema(implementation = CareLogDTO[].class))),
            @APIResponse(responseCode = "403", description = "Non membre de cette maison")
    })
    public Response getHouseActivity(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id,
            @Parameter(description = "Nombre d'activites (defaut 50, max 200)") @QueryParam("limit") @DefaultValue("50") int limit) {
        int effectiveLimit = Math.min(Math.max(limit, 1), 200);
        List<CareLogDTO> activity = houseService.getHouseActivity(getCurrentUserId(), id, effectiveLimit);
        return Response.ok(activity).build();
    }

    // ==================== VACATION / DELEGATION ====================

    @POST
    @Path("/{id}/vacation")
    @Operation(summary = "Activer le mode vacances", description = "Deleguer le soin de vos plantes a un autre membre de la maison pendant votre absence")
    @APIResponses({
            @APIResponse(responseCode = "201", description = "Mode vacances active",
                    content = @Content(schema = @Schema(implementation = VacationResponseDTO.class))),
            @APIResponse(responseCode = "400", description = "Donnees invalides ou delegation impossible"),
            @APIResponse(responseCode = "403", description = "Non membre de cette maison")
    })
    public Response activateVacation(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id,
            @Valid VacationRequestDTO request) {
        VacationResponseDTO response = vacationService.activateVacation(getCurrentUserId(), id, request);
        return Response.status(Response.Status.CREATED).entity(response).build();
    }

    @DELETE
    @Path("/{id}/vacation")
    @Operation(summary = "Annuler le mode vacances", description = "Retour anticipe : annule la delegation en cours")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Mode vacances annule"),
            @APIResponse(responseCode = "404", description = "Aucune delegation active")
    })
    public Response cancelVacation(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id) {
        vacationService.cancelVacation(getCurrentUserId(), id);
        return Response.noContent().build();
    }

    @GET
    @Path("/{id}/vacation")
    @Operation(summary = "Statut mode vacances", description = "Retourne la delegation active de l'utilisateur dans cette maison")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Statut vacances",
                    content = @Content(schema = @Schema(implementation = VacationResponseDTO.class))),
            @APIResponse(responseCode = "204", description = "Pas en mode vacances")
    })
    public Response getVacationStatus(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id) {
        VacationResponseDTO response = vacationService.getVacationStatus(getCurrentUserId(), id);
        if (response == null) {
            return Response.noContent().build();
        }
        return Response.ok(response).build();
    }

    @GET
    @Path("/{id}/delegations")
    @Operation(summary = "Delegations actives", description = "Liste toutes les delegations actives dans la maison (visible par tous les membres)")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Liste des delegations",
                    content = @Content(schema = @Schema(implementation = VacationResponseDTO[].class)))
    })
    public Response getHouseDelegations(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id) {
        List<VacationResponseDTO> delegations = vacationService.getHouseDelegations(getCurrentUserId(), id);
        return Response.ok(delegations).build();
    }

    @GET
    @Path("/{id}/my-delegations")
    @Operation(summary = "Mes delegations recues", description = "Liste les delegations ou l'utilisateur est le delegue (plantes dont il doit s'occuper)")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Delegations recues",
                    content = @Content(schema = @Schema(implementation = VacationResponseDTO[].class)))
    })
    public Response getMyDelegations(
            @Parameter(description = "ID de la maison", required = true) @PathParam("id") UUID id) {
        List<VacationResponseDTO> delegations = vacationService.getMyDelegations(getCurrentUserId(), id);
        return Response.ok(delegations).build();
    }
}
