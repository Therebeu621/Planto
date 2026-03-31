package com.plantmanager.resource;

import com.plantmanager.dto.*;
import com.plantmanager.entity.PlantPhotoEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.entity.enums.HealthStatus;
import com.plantmanager.service.FileStorageService;
import com.plantmanager.service.PlantService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.jboss.resteasy.reactive.RestForm;
import org.jboss.resteasy.reactive.multipart.FileUpload;

import java.io.FileInputStream;
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
 * REST Resource for plant management.
 * All endpoints require authentication.
 */
@Path("/plants")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Plant", description = "Gestion du jardin personnel")
@RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
public class PlantResource {

    @Inject
    PlantService plantService;

    @Inject
    FileStorageService fileStorageService;

    @Inject
    JsonWebToken jwt;

    /**
     * Get the current user's ID from the JWT.
     */
    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    // ==================== CREATE ====================

    @POST
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Ajouter une plante", description = "Créer une nouvelle plante dans le jardin")
    @APIResponses({
            @APIResponse(responseCode = "201", description = "Plante créée", content = @Content(schema = @Schema(implementation = PlantResponseDTO.class))),
            @APIResponse(responseCode = "400", description = "Données invalides"),
            @APIResponse(responseCode = "404", description = "Room ou Species non trouvée")
    })
    public Response createPlant(@Valid CreatePlantDTO request) {
        UserPlantEntity plant = plantService.createPlant(getCurrentUserId(), request);
        return Response.status(Response.Status.CREATED)
                .entity(PlantResponseDTO.from(plant))
                .build();
    }

    // ==================== READ (List) ====================

    @GET
    @Operation(summary = "Lister mes plantes", description = "Retourne toutes les plantes avec filtres optionnels")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Liste des plantes", content = @Content(schema = @Schema(implementation = PlantResponseDTO[].class)))
    })
    public Response getPlants(
            @Parameter(description = "Filtrer par pièce") @QueryParam("roomId") UUID roomId,

            @Parameter(description = "Filtrer par état de santé (GOOD, THIRSTY, SICK)") @QueryParam("status") HealthStatus status) {
        List<PlantResponseDTO> plants = plantService.getPlantsByUser(getCurrentUserId(), roomId, status);
        return Response.ok(plants).build();
    }

    // ==================== READ (Search) ====================

    @GET
    @Path("/search")
    @Operation(summary = "Rechercher des plantes", description = "Recherche textuelle par nickname")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Résultats de recherche", content = @Content(schema = @Schema(implementation = PlantResponseDTO[].class)))
    })
    public Response searchPlants(
            @Parameter(description = "Terme de recherche (min 2 caractères)", required = true) @QueryParam("q") String query) {
        if (query == null || query.length() < 2) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse("Query must be at least 2 characters"))
                    .build();
        }
        List<PlantResponseDTO> plants = plantService.searchPlants(getCurrentUserId(), query);
        return Response.ok(plants).build();
    }

    // ==================== READ (Detail) ====================

    @GET
    @Path("/{id}")
    @Operation(summary = "Détail d'une plante", description = "Retourne les informations complètes d'une plante")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Détails de la plante", content = @Content(schema = @Schema(implementation = PlantDetailDTO.class))),
            @APIResponse(responseCode = "404", description = "Plante non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response getPlant(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id) {
        PlantDetailDTO plant = plantService.getPlantDetail(getCurrentUserId(), id);
        return Response.ok(plant).build();
    }

    // ==================== UPDATE ====================

    @PUT
    @Path("/{id}")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Modifier une plante", description = "Mettre à jour les informations d'une plante")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Plante modifiée", content = @Content(schema = @Schema(implementation = PlantResponseDTO.class))),
            @APIResponse(responseCode = "404", description = "Plante ou Room non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response updatePlant(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id,
            @Valid UpdatePlantDTO request) {
        UserPlantEntity plant = plantService.updatePlant(getCurrentUserId(), id, request);
        return Response.ok(PlantResponseDTO.from(plant)).build();
    }

    // ==================== DELETE ====================

    @DELETE
    @Path("/{id}")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Supprimer une plante", description = "Supprimer définitivement une plante")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Plante supprimée"),
            @APIResponse(responseCode = "404", description = "Plante non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response deletePlant(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id) {
        plantService.deletePlant(getCurrentUserId(), id);
        return Response.noContent().build();
    }

    // ==================== WATER ====================

    @POST
    @Path("/{id}/water")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Arroser une plante", description = "Marquer la plante comme arrosée et créer un CareLog")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Plante arrosée", content = @Content(schema = @Schema(implementation = PlantResponseDTO.class))),
            @APIResponse(responseCode = "404", description = "Plante non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response waterPlant(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id) {
        UserPlantEntity plant = plantService.waterPlant(getCurrentUserId(), id);
        return Response.ok(PlantResponseDTO.from(plant)).build();
    }

    // ==================== CARE LOGS ====================

    @GET
    @Path("/{id}/care-logs")
    @Operation(summary = "Historique des soins", description = "Retourne l'historique complet des soins d'une plante (qui a fait quoi et quand)")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Historique des soins",
                    content = @Content(schema = @Schema(implementation = CareLogDTO[].class))),
            @APIResponse(responseCode = "404", description = "Plante non trouvee"),
            @APIResponse(responseCode = "403", description = "Acces refuse")
    })
    public Response getCareLogs(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id,
            @Parameter(description = "Filtrer par type d'action") @QueryParam("action") String action) {
        List<CareLogDTO> logs = plantService.getCareLogs(getCurrentUserId(), id, action);
        return Response.ok(logs).build();
    }

    @POST
    @Path("/{id}/care-logs")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Ajouter un soin", description = "Enregistrer une action de soin (fertilisation, rempotage, taille, traitement, note)")
    @APIResponses({
            @APIResponse(responseCode = "201", description = "Soin enregistre",
                    content = @Content(schema = @Schema(implementation = CareLogDTO.class))),
            @APIResponse(responseCode = "400", description = "Donnees invalides"),
            @APIResponse(responseCode = "404", description = "Plante non trouvee"),
            @APIResponse(responseCode = "403", description = "Acces refuse")
    })
    public Response createCareLog(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id,
            @Valid CreateCareLogDTO request) {
        CareLogDTO log = plantService.createCareLog(getCurrentUserId(), id, request);
        return Response.status(Response.Status.CREATED).entity(log).build();
    }

    @DELETE
    @Path("/{id}/care-logs/{logId}")
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Supprimer une note d'historique", description = "Supprime un care log de type NOTE pour la plante")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Note supprimee"),
            @APIResponse(responseCode = "404", description = "Note ou plante non trouvee"),
            @APIResponse(responseCode = "403", description = "Suppression non autorisee")
    })
    public Response deleteCareLog(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id,
            @Parameter(description = "ID du care log", required = true) @PathParam("logId") UUID logId) {
        plantService.deleteCareLog(getCurrentUserId(), id, logId);
        return Response.noContent().build();
    }

    // ==================== PHOTO ====================

    @POST
    @Path("/{id}/photo")
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Ajouter une photo", description = "Uploader une photo pour la plante")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Photo uploadee", content = @Content(schema = @Schema(implementation = PlantResponseDTO.class))),
            @APIResponse(responseCode = "400", description = "Fichier invalide"),
            @APIResponse(responseCode = "404", description = "Plante non trouvee"),
            @APIResponse(responseCode = "403", description = "Acces refuse")
    })
    public Response uploadPlantPhoto(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id,
            @RestForm("file") FileUpload file) {
        if (file == null || file.uploadedFile() == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse("Fichier requis"))
                    .build();
        }

        try (FileInputStream fis = new FileInputStream(file.uploadedFile().toFile())) {
            UUID userId = getCurrentUserId();
            UserPlantEntity plant = plantService.getPlantById(userId, id);
            UserEntity user = UserEntity.findById(userId);
            String previousPhotoPath = plant.photoPath;

            String relativePath = fileStorageService.storePlantPhoto(
                    id,
                    fis,
                    file.fileName(),
                    file.contentType()
            );

            PlantPhotoEntity primaryPhoto = PlantPhotoEntity.findPrimary(id);
            PlantPhotoEntity legacyPhoto = previousPhotoPath != null
                    ? PlantPhotoEntity.findByPlantAndPath(id, previousPhotoPath)
                    : null;
            PlantPhotoEntity photoToSync = primaryPhoto != null ? primaryPhoto : legacyPhoto;

            if (photoToSync == null) {
                PlantPhotoEntity newPrimaryPhoto = new PlantPhotoEntity();
                newPrimaryPhoto.plant = plant;
                newPrimaryPhoto.uploadedBy = user;
                newPrimaryPhoto.photoPath = relativePath;
                newPrimaryPhoto.isPrimary = true;
                newPrimaryPhoto.persist();
            } else {
                photoToSync.photoPath = relativePath;
                photoToSync.uploadedBy = user;
                photoToSync.isPrimary = true;
            }

            plant.photoPath = relativePath;
            plant.persist();

            if (previousPhotoPath != null && !previousPhotoPath.equals(relativePath)) {
                boolean stillReferenced = PlantPhotoEntity.findByPlantAndPath(id, previousPhotoPath) != null;
                if (!stillReferenced) {
                    fileStorageService.deleteFile(previousPhotoPath);
                }
            }

            return Response.ok(PlantResponseDTO.from(plant)).build();

        } catch (IllegalArgumentException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse(e.getMessage()))
                    .build();
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new ErrorResponse("Erreur lors de l'upload: " + e.getMessage()))
                    .build();
        }
    }

    @DELETE
    @Path("/{id}/photo")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER" })
    @Operation(summary = "Supprimer la photo", description = "Supprimer la photo de la plante")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Photo supprimee", content = @Content(schema = @Schema(implementation = PlantResponseDTO.class))),
            @APIResponse(responseCode = "404", description = "Plante non trouvee"),
            @APIResponse(responseCode = "403", description = "Acces refuse")
    })
    public Response deletePlantPhoto(
            @Parameter(description = "ID de la plante", required = true) @PathParam("id") UUID id) {
        UserPlantEntity plant = plantService.getPlantById(getCurrentUserId(), id);

        if (plant.photoPath != null) {
            String currentPhotoPath = plant.photoPath;
            PlantPhotoEntity galleryPhoto = PlantPhotoEntity.findByPlantAndPath(id, currentPhotoPath);

            if (galleryPhoto != null) {
                galleryPhoto.delete();

                List<PlantPhotoEntity> remainingPhotos = PlantPhotoEntity.findByPlant(id);
                if (!remainingPhotos.isEmpty()) {
                    PlantPhotoEntity nextPrimary = remainingPhotos.get(0);
                    nextPrimary.isPrimary = true;
                    plant.photoPath = nextPrimary.photoPath;
                } else {
                    plant.photoPath = null;
                }
            } else {
                plant.photoPath = null;
            }

            plant.persist();
            fileStorageService.deleteFile(currentPhotoPath);
        }

        return Response.ok(PlantResponseDTO.from(plant)).build();
    }

}
