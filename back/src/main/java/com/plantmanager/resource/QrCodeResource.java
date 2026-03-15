package com.plantmanager.resource;

import com.plantmanager.service.PlantService;
import com.plantmanager.service.QrCodeService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.UUID;

@Path("/qrcode")
@Tag(name = "QR Code", description = "Generation de QR codes pour les fiches plantes")
@RolesAllowed({"MEMBER", "OWNER", "GUEST"})
public class QrCodeResource {

    @Inject
    QrCodeService qrCodeService;

    @Inject
    PlantService plantService;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    @GET
    @Path("/plant/{plantId}")
    @Produces("image/png")
    @Operation(summary = "QR code plante", description = "Genere un QR code PNG pointant vers la fiche plante")
    public Response getPlantQrCode(
            @PathParam("plantId") UUID plantId,
            @QueryParam("size") @DefaultValue("300") int size) {
        // Verify access
        plantService.getPlantById(getCurrentUserId(), plantId);

        try {
            byte[] qrImage = qrCodeService.generatePlantQrCode(plantId, Math.min(size, 1000));
            return Response.ok(qrImage)
                    .header("Content-Disposition", "inline; filename=plant-" + plantId + ".png")
                    .build();
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .type(MediaType.APPLICATION_JSON)
                    .entity(new PlantResource.ErrorResponse("Erreur generation QR: " + e.getMessage()))
                    .build();
        }
    }
}
