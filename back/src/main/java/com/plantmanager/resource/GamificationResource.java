package com.plantmanager.resource;

import com.plantmanager.dto.GamificationProfileDTO;
import com.plantmanager.service.GamificationService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
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
 * REST Resource for gamification (XP, levels, badges, leaderboard).
 */
@Path("/gamification")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Gamification", description = "Systeme de niveaux, badges et classement")
@RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
public class GamificationResource {

    @Inject
    GamificationService gamificationService;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    @GET
    @Path("/profile")
    @Operation(summary = "Mon profil gamification", description = "Retourne XP, niveau, streak, badges (debloques et verrouilles)")
    @APIResponse(responseCode = "200", description = "Profil gamification",
                    content = @Content(schema = @Schema(implementation = GamificationProfileDTO.class)))
    public Response getProfile() {
        GamificationProfileDTO profile = gamificationService.getProfile(getCurrentUserId());
        return Response.ok(profile).build();
    }

    @GET
    @Path("/leaderboard/{houseId}")
    @Operation(summary = "Classement maison", description = "Classement des membres d'une maison par XP")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Classement",
                    content = @Content(schema = @Schema(implementation = GamificationProfileDTO[].class))),
            @APIResponse(responseCode = "403", description = "Non membre de cette maison")
    })
    public Response getHouseLeaderboard(
            @Parameter(description = "ID de la maison", required = true) @PathParam("houseId") UUID houseId) {
        List<GamificationProfileDTO> leaderboard = gamificationService.getHouseLeaderboard(getCurrentUserId(), houseId);
        return Response.ok(leaderboard).build();
    }
}
