package com.plantmanager.resource;

import com.plantmanager.dto.CreateGardenCultureDTO;
import com.plantmanager.dto.GardenCultureDTO;
import com.plantmanager.dto.UpdateCultureStatusDTO;
import com.plantmanager.service.GardenCultureService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.List;
import java.util.UUID;

@Path("/garden")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Potager", description = "Gestion du potager - semis, croissance, recolte")
@RolesAllowed({"MEMBER", "OWNER"})
public class GardenCultureResource {

    @Inject
    GardenCultureService gardenService;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    @POST
    @Path("/house/{houseId}")
    @Operation(summary = "Creer une culture", description = "Ajouter un nouveau semis au potager")
    public Response createCulture(
            @PathParam("houseId") UUID houseId,
            @Valid CreateGardenCultureDTO dto) {
        GardenCultureDTO culture = gardenService.createCulture(getCurrentUserId(), houseId, dto);
        return Response.status(Response.Status.CREATED).entity(culture).build();
    }

    @GET
    @Path("/house/{houseId}")
    @RolesAllowed({"MEMBER", "OWNER", "GUEST"})
    @Operation(summary = "Lister les cultures", description = "Toutes les cultures du potager d'une maison")
    public Response getCultures(
            @PathParam("houseId") UUID houseId,
            @QueryParam("status") String status) {
        List<GardenCultureDTO> cultures = gardenService.getCulturesByHouse(getCurrentUserId(), houseId, status);
        return Response.ok(cultures).build();
    }

    @GET
    @Path("/{cultureId}")
    @RolesAllowed({"MEMBER", "OWNER", "GUEST"})
    @Operation(summary = "Detail d'une culture", description = "Informations completes avec historique de croissance")
    public Response getCulture(@PathParam("cultureId") UUID cultureId) {
        GardenCultureDTO culture = gardenService.getCultureById(getCurrentUserId(), cultureId);
        return Response.ok(culture).build();
    }

    @PUT
    @Path("/{cultureId}/status")
    @Operation(summary = "Mettre a jour le statut", description = "Faire progresser une culture (semis -> germination -> croissance -> recolte)")
    public Response updateStatus(
            @PathParam("cultureId") UUID cultureId,
            @Valid UpdateCultureStatusDTO dto) {
        GardenCultureDTO culture = gardenService.updateStatus(getCurrentUserId(), cultureId, dto);
        return Response.ok(culture).build();
    }

    @DELETE
    @Path("/{cultureId}")
    @Operation(summary = "Supprimer une culture")
    public Response deleteCulture(@PathParam("cultureId") UUID cultureId) {
        gardenService.deleteCulture(getCurrentUserId(), cultureId);
        return Response.noContent().build();
    }
}
