package com.plantmanager.resource;

import com.plantmanager.dto.PlantPhotoDTO;
import com.plantmanager.entity.PlantPhotoEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.service.FileStorageService;
import com.plantmanager.service.PlantService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jboss.resteasy.reactive.RestForm;
import org.jboss.resteasy.reactive.multipart.FileUpload;

import java.io.FileInputStream;
import java.util.List;
import java.util.UUID;

@Path("/plants/{plantId}/photos")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "Galerie Photo", description = "Galerie multi-photos par plante")
@RolesAllowed({"MEMBER", "OWNER", "GUEST"})
public class PlantPhotoResource {

    @Inject
    PlantService plantService;

    @Inject
    FileStorageService fileStorageService;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    @GET
    @Operation(summary = "Galerie photos", description = "Toutes les photos d'une plante")
    public Response getPhotos(@PathParam("plantId") UUID plantId) {
        plantService.getPlantById(getCurrentUserId(), plantId);
        List<PlantPhotoDTO> photos = PlantPhotoEntity.findByPlant(plantId)
                .stream().map(PlantPhotoDTO::from).toList();
        return Response.ok(photos).build();
    }

    @POST
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    @Transactional
    @RolesAllowed({"MEMBER", "OWNER"})
    @Operation(summary = "Ajouter une photo", description = "Uploader une photo dans la galerie")
    public Response addPhoto(
            @PathParam("plantId") UUID plantId,
            @RestForm("file") FileUpload file,
            @RestForm("caption") String caption,
            @RestForm("isPrimary") Boolean isPrimary) {

        if (file == null || file.uploadedFile() == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new PlantResource.ErrorResponse("Fichier requis")).build();
        }

        try (FileInputStream fis = new FileInputStream(file.uploadedFile().toFile())) {
            UUID userId = getCurrentUserId();
            UserPlantEntity plant = plantService.getPlantById(userId, plantId);
            UserEntity user = UserEntity.findById(userId);

            String relativePath = fileStorageService.storePlantPhoto(
                    plantId,
                    fis,
                    file.fileName(),
                    file.contentType());

            // If setting as primary, unset current primary
            if (isPrimary != null && isPrimary) {
                PlantPhotoEntity currentPrimary = PlantPhotoEntity.findPrimary(plantId);
                if (currentPrimary != null) {
                    currentPrimary.isPrimary = false;
                }
            }

            boolean makePrimary = (isPrimary != null && isPrimary) || PlantPhotoEntity.countByPlant(plantId) == 0;

            PlantPhotoEntity photo = new PlantPhotoEntity();
            photo.plant = plant;
            photo.uploadedBy = user;
            photo.photoPath = relativePath;
            photo.caption = caption;
            photo.isPrimary = makePrimary;
            photo.persist();

            // Update plant's main photo path
            if (makePrimary) {
                plant.photoPath = relativePath;
            }

            return Response.status(Response.Status.CREATED).entity(PlantPhotoDTO.from(photo)).build();

        } catch (NotFoundException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new PlantResource.ErrorResponse(e.getMessage())).build();
        } catch (IllegalArgumentException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new PlantResource.ErrorResponse(e.getMessage())).build();
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new PlantResource.ErrorResponse("Erreur upload: " + e.getMessage())).build();
        }
    }

    @PUT
    @Path("/{photoId}/primary")
    @Transactional
    @RolesAllowed({"MEMBER", "OWNER"})
    @Operation(summary = "Definir photo principale")
    public Response setPrimary(
            @PathParam("plantId") UUID plantId,
            @PathParam("photoId") UUID photoId) {

        UserPlantEntity plant = plantService.getPlantById(getCurrentUserId(), plantId);

        PlantPhotoEntity photo = PlantPhotoEntity.findById(photoId);
        if (photo == null || !photo.plant.id.equals(plantId)) {
            throw new NotFoundException("Photo not found");
        }

        // Unset current primary
        PlantPhotoEntity currentPrimary = PlantPhotoEntity.findPrimary(plantId);
        if (currentPrimary != null) {
            currentPrimary.isPrimary = false;
        }

        photo.isPrimary = true;
        plant.photoPath = photo.photoPath;

        return Response.ok(PlantPhotoDTO.from(photo)).build();
    }

    @DELETE
    @Path("/{photoId}")
    @Transactional
    @RolesAllowed({"MEMBER", "OWNER"})
    @Operation(summary = "Supprimer une photo")
    public Response deletePhoto(
            @PathParam("plantId") UUID plantId,
            @PathParam("photoId") UUID photoId) {

        UserPlantEntity plant = plantService.getPlantById(getCurrentUserId(), plantId);

        PlantPhotoEntity photo = PlantPhotoEntity.findById(photoId);
        if (photo == null || !photo.plant.id.equals(plantId)) {
            throw new NotFoundException("Photo not found");
        }

        fileStorageService.deleteFile(photo.photoPath);

        boolean wasPrimary = photo.isPrimary;
        photo.delete();

        // If deleted primary, set next photo as primary
        if (wasPrimary) {
            List<PlantPhotoEntity> remaining = PlantPhotoEntity.findByPlant(plantId);
            if (!remaining.isEmpty()) {
                remaining.get(0).isPrimary = true;
                plant.photoPath = remaining.get(0).photoPath;
            } else {
                plant.photoPath = null;
            }
        }

        return Response.noContent().build();
    }
}
