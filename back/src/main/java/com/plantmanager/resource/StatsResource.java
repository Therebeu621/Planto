package com.plantmanager.resource;

import com.plantmanager.dto.AnnualStatsDTO;
import com.plantmanager.dto.DashboardDTO;
import com.plantmanager.service.StatsService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.time.Year;
import java.util.UUID;

@Path("/stats")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Statistiques", description = "Dashboard analytique et retrospective annuelle")
@RolesAllowed({"MEMBER", "OWNER", "GUEST"})
public class StatsResource {

    @Inject
    StatsService statsService;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    @GET
    @Path("/dashboard")
    @Operation(summary = "Dashboard", description = "Vue d'ensemble avec analytique, classements et activite recente")
    public Response getDashboard() {
        DashboardDTO dashboard = statsService.getDashboard(getCurrentUserId());
        return Response.ok(dashboard).build();
    }

    @GET
    @Path("/annual")
    @Operation(summary = "Retrospective annuelle", description = "Statistiques completes pour une annee donnee")
    public Response getAnnualStats(@QueryParam("year") @DefaultValue("0") int year) {
        int targetYear = year > 0 ? year : Year.now().getValue();
        AnnualStatsDTO stats = statsService.getAnnualStats(getCurrentUserId(), targetYear);
        return Response.ok(stats).build();
    }
}
