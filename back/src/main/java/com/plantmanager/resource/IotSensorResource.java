package com.plantmanager.resource;

import com.plantmanager.dto.*;
import com.plantmanager.service.IotSensorService;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Path("/iot")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "IoT Capteurs", description = "Integration capteurs Arduino - humidite, temperature, luminosite, pH")
public class IotSensorResource {

    @Inject
    IotSensorService sensorService;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    @POST
    @Path("/house/{houseId}/sensors")
    @RolesAllowed({"MEMBER", "OWNER"})
    @Operation(summary = "Enregistrer un capteur", description = "Associer un nouveau capteur Arduino a une maison")
    public Response createSensor(
            @PathParam("houseId") UUID houseId,
            @Valid CreateSensorDTO dto) {
        IotSensorDTO sensor = sensorService.createSensor(getCurrentUserId(), houseId, dto);
        return Response.status(Response.Status.CREATED).entity(sensor).build();
    }

    @GET
    @Path("/house/{houseId}/sensors")
    @RolesAllowed({"MEMBER", "OWNER", "GUEST"})
    @Operation(summary = "Capteurs d'une maison", description = "Lister tous les capteurs d'une maison")
    public Response getSensorsByHouse(@PathParam("houseId") UUID houseId) {
        List<IotSensorDTO> sensors = sensorService.getSensorsByHouse(getCurrentUserId(), houseId);
        return Response.ok(sensors).build();
    }

    @GET
    @Path("/plant/{plantId}/sensors")
    @RolesAllowed({"MEMBER", "OWNER", "GUEST"})
    @Operation(summary = "Capteurs d'une plante", description = "Capteurs associes a une plante")
    public Response getSensorsByPlant(@PathParam("plantId") UUID plantId) {
        List<IotSensorDTO> sensors = sensorService.getSensorsByPlant(getCurrentUserId(), plantId);
        return Response.ok(sensors).build();
    }

    @POST
    @Path("/sensors/{sensorId}/readings")
    @PermitAll
    @Operation(summary = "Envoyer une mesure", description = "Endpoint pour Arduino/ESP - envoie une valeur de capteur")
    public Response submitReading(
            @PathParam("sensorId") UUID sensorId,
            @Valid SubmitReadingDTO dto) {
        SensorReadingDTO reading = sensorService.submitReading(sensorId, dto);
        return Response.status(Response.Status.CREATED).entity(reading).build();
    }

    @GET
    @Path("/sensors/{sensorId}/readings")
    @RolesAllowed({"MEMBER", "OWNER", "GUEST"})
    @Operation(summary = "Historique des mesures", description = "Donnees du capteur pour graphiques temporels")
    public Response getReadings(
            @PathParam("sensorId") UUID sensorId,
            @QueryParam("limit") @DefaultValue("100") int limit,
            @QueryParam("from") String from,
            @QueryParam("to") String to) {

        if (from != null && to != null) {
            List<SensorReadingDTO> readings = sensorService.getReadingsBetween(
                    getCurrentUserId(), sensorId,
                    OffsetDateTime.parse(from), OffsetDateTime.parse(to));
            return Response.ok(readings).build();
        }

        List<SensorReadingDTO> readings = sensorService.getReadings(getCurrentUserId(), sensorId, limit);
        return Response.ok(readings).build();
    }

    @DELETE
    @Path("/sensors/{sensorId}")
    @RolesAllowed({"MEMBER", "OWNER"})
    @Operation(summary = "Supprimer un capteur")
    public Response deleteSensor(@PathParam("sensorId") UUID sensorId) {
        sensorService.deleteSensor(getCurrentUserId(), sensorId);
        return Response.noContent().build();
    }
}
