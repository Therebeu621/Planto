package com.plantmanager.resource;

import com.plantmanager.dto.NotificationDTO;
import com.plantmanager.service.NotificationService;
import com.plantmanager.service.WateringReminderScheduler;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * REST Resource for notification management.
 * Provides endpoints for listing, reading, and managing user notifications.
 */
@Path("/notifications")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Notification", description = "Gestion des notifications")
@RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
public class NotificationResource {

    @Inject
    NotificationService notificationService;

    @Inject
    WateringReminderScheduler reminderScheduler;

    @Inject
    JsonWebToken jwt;

    private UUID getCurrentUserId() {
        return UUID.fromString(jwt.getSubject());
    }

    // ==================== LIST ====================

    @GET
    @Operation(summary = "Lister mes notifications", description = "Retourne toutes les notifications de l'utilisateur, triées par date décroissante")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Liste des notifications",
                    content = @Content(schema = @Schema(implementation = NotificationDTO[].class)))
    })
    public Response getNotifications(
            @QueryParam("unreadOnly") @DefaultValue("false") boolean unreadOnly) {
        UUID userId = getCurrentUserId();
        List<NotificationDTO> notifications;

        if (unreadOnly) {
            notifications = notificationService.getUnreadNotifications(userId);
        } else {
            notifications = notificationService.getNotificationsByUser(userId);
        }

        return Response.ok(notifications).build();
    }

    // ==================== UNREAD COUNT ====================

    @GET
    @Path("/unread-count")
    @Operation(summary = "Nombre de notifications non lues", description = "Retourne le nombre de notifications non lues")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Nombre de non lues")
    })
    public Response getUnreadCount() {
        long count = notificationService.countUnread(getCurrentUserId());
        return Response.ok(Map.of("unreadCount", count)).build();
    }

    // ==================== MARK AS READ ====================

    @PUT
    @Path("/{id}/read")
    @Operation(summary = "Marquer une notification comme lue", description = "Met à jour le statut d'une notification")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Notification marquée comme lue",
                    content = @Content(schema = @Schema(implementation = NotificationDTO.class))),
            @APIResponse(responseCode = "404", description = "Notification non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response markAsRead(@PathParam("id") UUID id) {
        NotificationDTO dto = notificationService.markAsRead(getCurrentUserId(), id);
        return Response.ok(dto).build();
    }

    // ==================== MARK ALL AS READ ====================

    @PUT
    @Path("/read-all")
    @Operation(summary = "Tout marquer comme lu", description = "Marque toutes les notifications comme lues")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Notifications marquées comme lues")
    })
    public Response markAllAsRead() {
        int count = notificationService.markAllAsRead(getCurrentUserId());
        return Response.ok(Map.of("markedAsRead", count)).build();
    }

    // ==================== TRIGGER REMINDERS (for testing) ====================

    @POST
    @Path("/trigger-reminders")
    @Operation(summary = "Declencher les rappels manuellement", description = "Permet de tester le systeme de rappels sans attendre le cron. Execute le rappel d'arrosage et le rappel de soin.")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Rappels declenches")
    })
    public Response triggerReminders() {
        reminderScheduler.sendDailyWateringReminders();
        reminderScheduler.sendWeeklyCareReminders();
        return Response.ok(Map.of("status", "Reminders triggered successfully")).build();
    }

    // ==================== DELETE ====================

    @DELETE
    @Path("/{id}")
    @Operation(summary = "Supprimer une notification", description = "Supprime une notification de l'utilisateur")
    @APIResponses({
            @APIResponse(responseCode = "204", description = "Notification supprimée"),
            @APIResponse(responseCode = "404", description = "Notification non trouvée"),
            @APIResponse(responseCode = "403", description = "Accès refusé")
    })
    public Response deleteNotification(@PathParam("id") UUID id) {
        notificationService.deleteNotification(getCurrentUserId(), id);
        return Response.noContent().build();
    }
}
