package com.plantmanager.resource;

import com.plantmanager.entity.CareLogEntity;
import com.plantmanager.entity.UserPlantEntity;
import jakarta.annotation.security.PermitAll;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.time.format.DateTimeFormatter;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.UUID;

/**
 * Public endpoint for plant info pages (no authentication required).
 * Used by QR codes so anyone can scan and see plant details.
 */
@Path("/public/plant")
@Tag(name = "Public", description = "Pages publiques accessibles sans authentification")
@PermitAll
public class PublicPlantResource {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    @GET
    @Path("/{plantId}")
    @Produces(MediaType.TEXT_HTML)
    @Operation(summary = "Fiche plante publique",
            description = "Page HTML publique avec les infos de la plante, accessible via QR code")
    public Response getPlantPage(@PathParam("plantId") UUID plantId) {
        UserPlantEntity plant = UserPlantEntity.findById(plantId);
        if (plant == null) {
            return Response.status(404)
                    .type(MediaType.TEXT_HTML)
                    .entity(buildErrorPage("Plante introuvable",
                            "Cette plante n'existe pas ou a ete supprimee."))
                    .build();
        }

        return Response.ok(buildPlantPage(plant))
                .header("Cache-Control", "public, max-age=300")
                .build();
    }

    private String buildPlantPage(UserPlantEntity plant) {
        String name = escapeHtml(plant.nickname != null ? plant.nickname : "Plante");
        String speciesName = "";
        String family = "";
        String imageUrl = "";

        if (plant.species != null) {
            if (plant.species.scientificName != null)
                speciesName = escapeHtml(plant.species.scientificName);
            if (plant.species.family != null)
                family = escapeHtml(plant.species.family);
            if (plant.species.imageUrl != null)
                imageUrl = escapeHtml(plant.species.imageUrl);
        }
        if (speciesName.isEmpty() && plant.customSpecies != null) {
            speciesName = escapeHtml(plant.customSpecies);
        }

        String exposureText = switch (plant.exposure) {
            case SUN -> "Plein soleil";
            case SHADE -> "Ombre";
            case PARTIAL_SHADE -> "Mi-ombre";
            case null -> "Non renseigne";
        };

        String wateringInfo = plant.wateringIntervalDays != null
                ? "Tous les " + plant.wateringIntervalDays + " jours"
                : "Non renseigne";

        String nextWatering = "";
        LocalDate next = plant.getNextWateringDate();
        if (next != null) {
            if (!next.isAfter(LocalDate.now())) {
                nextWatering = "<span style='color:#e74c3c;font-weight:600'>A arroser maintenant !</span>";
            } else {
                nextWatering = next.format(DATE_FMT);
            }
        }

        // Health badges
        StringBuilder badges = new StringBuilder();
        if (plant.needsWatering()) badges.append(badge("Soif", "#e74c3c"));
        if (plant.isSick) badges.append(badge("Malade", "#e67e22"));
        if (plant.isWilted) badges.append(badge("Fanee", "#9b59b6"));
        if (plant.needsRepotting) badges.append(badge("A rempoter", "#8B4513"));
        if (badges.isEmpty()) badges.append(badge("En forme", "#27ae60"));

        // Recent care logs
        StringBuilder careHtml = new StringBuilder();
        var logs = plant.careLogs.stream()
                .sorted(Comparator.comparing((CareLogEntity l) -> l.performedAt).reversed())
                .limit(5)
                .toList();
        if (!logs.isEmpty()) {
            careHtml.append("<div class='section'><h3>Derniers soins</h3><div class='care-list'>");
            for (var log : logs) {
                String action = switch (log.action.name()) {
                    case "WATERING" -> "Arrosage";
                    case "FERTILIZING" -> "Fertilisation";
                    case "PRUNING" -> "Taille";
                    case "TREATMENT" -> "Traitement";
                    case "NOTE" -> "Memo";
                    default -> log.action.name();
                };
                String date = log.performedAt != null ? log.performedAt.format(DATE_FMT) : "";
                String notes = log.notes != null ? " - " + escapeHtml(log.notes) : "";
                careHtml.append("<div class='care-item'><span class='care-action'>")
                        .append(action).append("</span><span class='care-date'>")
                        .append(date).append("</span>")
                        .append(notes.isEmpty() ? "" : "<div class='care-notes'>" + notes + "</div>")
                        .append("</div>");
            }
            careHtml.append("</div></div>");
        }

        // Notes
        String notesHtml = "";
        if (plant.notes != null && !plant.notes.isBlank()) {
            notesHtml = "<div class='section'><h3>Notes</h3><p class='notes'>"
                    + escapeHtml(plant.notes) + "</p></div>";
        }

        // Pot info
        String potHtml = "";
        if (plant.potDiameterCm != null) {
            potHtml = "<div class='info-item'><span class='label'>Pot</span><span class='value'>"
                    + plant.potDiameterCm + " cm</span></div>";
        }

        // Room
        String roomHtml = "";
        if (plant.room != null && plant.room.name != null) {
            roomHtml = "<div class='info-item'><span class='label'>Piece</span><span class='value'>"
                    + escapeHtml(plant.room.name) + "</span></div>";
        }

        // Image section
        String imageHtml = imageUrl.isEmpty()
                ? "<div class='plant-icon'>&#127793;</div>"
                : "<img src='" + imageUrl + "' alt='" + name + "' class='plant-img'/>";

        return """
                <!DOCTYPE html>
                <html lang="fr">
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>%s - Planto</title>
                    <style>
                        * { margin: 0; padding: 0; box-sizing: border-box; }
                        body {
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                            background: linear-gradient(135deg, #e8f5e9 0%%, #f1f8e9 100%%);
                            min-height: 100vh; padding: 20px;
                            color: #2c3e50;
                        }
                        .card {
                            max-width: 480px; margin: 0 auto;
                            background: white; border-radius: 24px;
                            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
                            overflow: hidden;
                        }
                        .header {
                            background: linear-gradient(135deg, #4CAF50, #66BB6A);
                            padding: 32px 24px; text-align: center; color: white;
                        }
                        .plant-img {
                            width: 120px; height: 120px; border-radius: 50%%;
                            object-fit: cover; border: 4px solid rgba(255,255,255,0.3);
                            margin-bottom: 16px;
                        }
                        .plant-icon {
                            font-size: 64px; margin-bottom: 16px;
                        }
                        .header h1 { font-size: 24px; margin-bottom: 4px; }
                        .header .species { opacity: 0.9; font-style: italic; font-size: 14px; }
                        .header .family { opacity: 0.7; font-size: 12px; margin-top: 4px; }
                        .badges { display: flex; gap: 8px; justify-content: center; margin-top: 12px; flex-wrap: wrap; }
                        .badge {
                            padding: 4px 12px; border-radius: 20px;
                            font-size: 12px; font-weight: 600; color: white;
                        }
                        .content { padding: 24px; }
                        .section { margin-bottom: 20px; }
                        .section h3 {
                            font-size: 14px; text-transform: uppercase;
                            color: #4CAF50; margin-bottom: 12px; letter-spacing: 0.5px;
                        }
                        .info-grid {
                            display: grid; grid-template-columns: 1fr 1fr; gap: 12px;
                        }
                        .info-item {
                            background: #f8f9fa; border-radius: 12px; padding: 12px;
                        }
                        .info-item .label {
                            font-size: 11px; text-transform: uppercase; color: #999;
                            display: block; margin-bottom: 4px;
                        }
                        .info-item .value { font-size: 15px; font-weight: 600; }
                        .care-list { display: flex; flex-direction: column; gap: 8px; }
                        .care-item {
                            background: #f8f9fa; border-radius: 12px; padding: 12px;
                            display: flex; flex-wrap: wrap; align-items: center; gap: 8px;
                        }
                        .care-action { font-weight: 600; font-size: 14px; }
                        .care-date { color: #999; font-size: 12px; margin-left: auto; }
                        .care-notes { width: 100%%; font-size: 12px; color: #666; }
                        .notes {
                            background: #f8f9fa; border-radius: 12px; padding: 12px;
                            font-size: 14px; line-height: 1.5; color: #555;
                        }
                        .footer {
                            text-align: center; padding: 16px 24px 24px;
                            color: #999; font-size: 12px;
                        }
                        .footer .app-name {
                            color: #4CAF50; font-weight: 700; font-size: 14px;
                        }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <div class="header">
                            %s
                            <h1>%s</h1>
                            %s
                            %s
                            <div class="badges">%s</div>
                        </div>
                        <div class="content">
                            <div class="section">
                                <h3>Informations</h3>
                                <div class="info-grid">
                                    <div class="info-item">
                                        <span class="label">Arrosage</span>
                                        <span class="value">%s</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="label">Prochain arrosage</span>
                                        <span class="value">%s</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="label">Exposition</span>
                                        <span class="value">%s</span>
                                    </div>
                                    %s
                                    %s
                                </div>
                            </div>
                            %s
                            %s
                        </div>
                        <div class="footer">
                            <span class="app-name">Planto</span> - Gestionnaire de plantes
                        </div>
                    </div>
                </body>
                </html>
                """.formatted(
                name,
                imageHtml,
                name,
                speciesName.isEmpty() ? "" : "<div class='species'>" + speciesName + "</div>",
                family.isEmpty() ? "" : "<div class='family'>" + family + "</div>",
                badges.toString(),
                wateringInfo,
                nextWatering.isEmpty() ? "-" : nextWatering,
                exposureText,
                potHtml,
                roomHtml,
                careHtml.toString(),
                notesHtml
        );
    }

    private String buildErrorPage(String title, String message) {
        return """
                <!DOCTYPE html>
                <html lang="fr">
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>%s - Planto</title>
                    <style>
                        body {
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                            background: #f5f5f5; display: flex; align-items: center;
                            justify-content: center; min-height: 100vh; margin: 0;
                        }
                        .card {
                            background: white; border-radius: 24px; padding: 48px;
                            text-align: center; max-width: 400px;
                            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
                        }
                        .icon { font-size: 64px; margin-bottom: 16px; }
                        h1 { color: #2c3e50; margin-bottom: 8px; }
                        p { color: #999; }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <div class="icon">&#127793;</div>
                        <h1>%s</h1>
                        <p>%s</p>
                    </div>
                </body>
                </html>
                """.formatted(title, title, message);
    }

    private static String badge(String text, String color) {
        return "<span class='badge' style='background:" + color + "'>" + text + "</span>";
    }

    private static String escapeHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }
}
