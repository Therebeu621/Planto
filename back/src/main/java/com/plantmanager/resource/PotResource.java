package com.plantmanager.resource;

import com.plantmanager.dto.*;
import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.service.PotService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.List;
import java.util.UUID;

/**
 * REST Resource for pot stock management.
 */
@Path("/pots")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Pot Stock", description = "Gestion du stock de pots")
@RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
public class PotResource {

    @Inject
    PotService potService;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    // ==================== STOCK CRUD ====================

    @GET
    @Operation(summary = "Lister le stock de pots", description = "Retourne tous les pots de la maison active")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Liste des pots")
    })
    public Response getPotStock() {
        List<PotStockDTO> pots = potService.getPotStock(getCurrentUserId());
        return Response.ok(pots).build();
    }

    @GET
    @Path("/available")
    @Operation(summary = "Pots disponibles", description = "Retourne les pots avec stock > 0")
    public Response getAvailablePots() {
        List<PotStockDTO> pots = potService.getAvailablePots(getCurrentUserId());
        return Response.ok(pots).build();
    }

    @POST
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Ajouter des pots au stock", description = "Ajouter des pots. Si le diametre existe deja, la quantite est incrementee.")
    @APIResponses({
            @APIResponse(responseCode = "201", description = "Pot ajoute au stock"),
            @APIResponse(responseCode = "400", description = "Donnees invalides")
    })
    public Response addToStock(@Valid CreatePotStockDTO request) {
        PotStockDTO pot = potService.addToStock(getCurrentUserId(), request);
        return Response.status(Response.Status.CREATED).entity(pot).build();
    }

    @PUT
    @Path("/{id}")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Modifier la quantite", description = "Mettre a jour la quantite d'un pot en stock")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Stock mis a jour"),
            @APIResponse(responseCode = "404", description = "Pot non trouve")
    })
    public Response updateStock(@PathParam("id") UUID id, UpdatePotStockDTO request) {
        PotStockDTO pot = potService.updateStock(getCurrentUserId(), id, request.quantity());
        return Response.ok(pot).build();
    }

    @DELETE
    @Path("/{id}")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Supprimer du stock", description = "Supprimer une entree de pot du stock")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Pot supprime"),
            @APIResponse(responseCode = "404", description = "Pot non trouve")
    })
    public Response deleteStock(@PathParam("id") UUID id) {
        potService.deleteStock(getCurrentUserId(), id);
        return Response.noContent().build();
    }

    // ==================== REPOTTING ====================

    @POST
    @Path("/repot/{plantId}")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Rempoter une plante",
            description = "Rempote une plante: prend le nouveau pot du stock, retourne l'ancien pot au stock, met a jour la plante")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Plante rempotee"),
            @APIResponse(responseCode = "400", description = "Pot non disponible en stock"),
            @APIResponse(responseCode = "404", description = "Plante ou pot non trouve")
    })
    public Response repotPlant(@PathParam("plantId") UUID plantId, @Valid RepotDTO request) {
        UserPlantEntity plant = potService.repotPlant(getCurrentUserId(), plantId, request);
        return Response.ok(PlantResponseDTO.from(plant)).build();
    }

    @GET
    @Path("/suggestions/{plantId}")
    @Operation(summary = "Pots suggeres pour rempotage",
            description = "Retourne les pots disponibles plus grands que le pot actuel de la plante")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Liste des pots suggeres"),
            @APIResponse(responseCode = "404", description = "Plante non trouvee")
    })
    public Response getSuggestedPots(@PathParam("plantId") UUID plantId) {
        List<PotStockDTO> pots = potService.getSuggestedPots(getCurrentUserId(), plantId);
        return Response.ok(pots).build();
    }
}
