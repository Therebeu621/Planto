package com.plantmanager.resource;

import com.plantmanager.dto.CreateRoomDTO;
import com.plantmanager.dto.RoomResponseDTO;
import com.plantmanager.dto.UpdateRoomDTO;
import com.plantmanager.entity.RoomEntity;
import com.plantmanager.service.RoomService;
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
 * REST Resource for room management.
 * All endpoints require authentication.
 */
@Path("/rooms")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Room", description = "Gestion des pièces")
@RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
public class RoomResource {

    @Inject
    RoomService roomService;

    @Inject
    JsonWebToken jwt;

    /**
     * Get the current user's ID from the JWT.
     */
    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    // ==================== LIST ====================

    @GET
    @Operation(summary = "Lister les pièces de ma maison", description = "Retourne toutes les pièces avec leurs plantes incluses")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Liste des pièces", content = @Content(schema = @Schema(implementation = RoomResponseDTO[].class)))
    })
    public Response getRooms(
            @Parameter(description = "Inclure les plantes dans la réponse") @QueryParam("includePlants") @DefaultValue("true") boolean includePlants) {
        List<RoomResponseDTO> rooms = roomService.getRoomsByUser(getCurrentUserId(), includePlants);
        return Response.ok(rooms).build();
    }

    // ==================== DETAIL ====================

    @GET
    @Path("/{id}")
    @Operation(summary = "Détail d'une pièce", description = "Retourne les informations d'une pièce avec ses plantes")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Détails de la pièce", content = @Content(schema = @Schema(implementation = RoomResponseDTO.class))),
            @APIResponse(responseCode = "404", description = "Pièce non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response getRoom(
            @Parameter(description = "ID de la pièce", required = true) @PathParam("id") UUID id) {
        RoomResponseDTO room = roomService.getRoomDetail(getCurrentUserId(), id);
        return Response.ok(room).build();
    }

    // ==================== CREATE ====================

    @POST
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Créer une pièce", description = "Ajouter une nouvelle pièce à la maison")
    @APIResponses({
            @APIResponse(responseCode = "201", description = "Pièce créée", content = @Content(schema = @Schema(implementation = RoomResponseDTO.class))),
            @APIResponse(responseCode = "400", description = "Données invalides"),
            @APIResponse(responseCode = "403", description = "Pas de maison associée")
    })
    public Response createRoom(@Valid CreateRoomDTO request) {
        RoomEntity room = roomService.createRoom(getCurrentUserId(), request);
        return Response.status(Response.Status.CREATED)
                .entity(RoomResponseDTO.fromWithoutPlants(room))
                .build();
    }

    // ==================== UPDATE ====================

    @PATCH
    @Path("/{id}")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Modifier une pièce", description = "Mettre à jour les informations d'une pièce")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Pièce modifiée", content = @Content(schema = @Schema(implementation = RoomResponseDTO.class))),
            @APIResponse(responseCode = "404", description = "Pièce non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response updateRoom(
            @Parameter(description = "ID de la pièce", required = true) @PathParam("id") UUID id,
            @Valid UpdateRoomDTO request) {
        RoomEntity room = roomService.updateRoom(getCurrentUserId(), id, request);
        return Response.ok(RoomResponseDTO.fromWithoutPlants(room)).build();
    }

    // ==================== DELETE ====================

    @DELETE
    @Path("/{id}")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Supprimer une pièce", description = "Supprimer une pièce. Les plantes associées auront leur room_id mis à NULL.")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Pièce supprimée"),
            @APIResponse(responseCode = "404", description = "Pièce non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response deleteRoom(
            @Parameter(description = "ID de la pièce", required = true) @PathParam("id") UUID id) {
        roomService.deleteRoom(getCurrentUserId(), id);
        return Response.noContent().build();
    }
}
