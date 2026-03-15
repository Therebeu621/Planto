package com.plantmanager.service;

import com.plantmanager.dto.weather.WeatherWateringAdviceDTO;
import com.plantmanager.entity.NotificationEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.entity.enums.NotificationType;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.jboss.logging.Logger;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Scheduled service for smart watering reminders.
 * Runs daily and sends grouped notifications with personalized care recommendations.
 *
 * Features:
 * - Groups multiple plants per user into a single notification (rappels regroupés)
 * - Includes personalized care tips based on plant species (recommandations personnalisées)
 * - Creates in-app notifications + sends FCM push notifications
 * - Prioritizes plants by urgency (overdue vs due today)
 */
@ApplicationScoped
public class WateringReminderScheduler {

    private static final Logger LOG = Logger.getLogger(WateringReminderScheduler.class);

    @Inject
    FcmService fcmService;

    @Inject
    NotificationService notificationService;

    @Inject
    VacationService vacationService;

    @Inject
    WeatherService weatherService;

    /**
     * Daily watering reminder - runs every day at 8:00 AM.
     * Groups all plants needing water per user and sends a single grouped notification.
     */
    @Scheduled(cron = "${watering.reminder.cron:0 0 8 * * ?}")
    @Transactional
    public void sendDailyWateringReminders() {
        LOG.info("=== Starting daily watering reminder check ===");

        List<UserPlantEntity> plantsNeedingWater = UserPlantEntity.findAllNeedingWaterToday();

        if (plantsNeedingWater.isEmpty()) {
            LOG.info("No plants need watering today");
            return;
        }

        LOG.infof("Found %d plants needing water across all users", plantsNeedingWater.size());

        // Group plants by user
        Map<UUID, List<UserPlantEntity>> plantsByUser = plantsNeedingWater.stream()
                .collect(Collectors.groupingBy(p -> p.user.id));

        // Redirect reminders to delegates for users on vacation
        Map<UUID, List<UserPlantEntity>> effectiveRecipients = new HashMap<>();

        for (Map.Entry<UUID, List<UserPlantEntity>> entry : plantsByUser.entrySet()) {
            UUID ownerId = entry.getKey();
            List<UserPlantEntity> userPlants = entry.getValue();

            UUID delegateId = vacationService.getDelegateForUser(ownerId);
            if (delegateId != null) {
                // Owner is on vacation -> redirect to delegate
                LOG.infof("User %s is on vacation, redirecting %d plant reminders to delegate %s",
                        ownerId, userPlants.size(), delegateId);
                effectiveRecipients.computeIfAbsent(delegateId, k -> new ArrayList<>()).addAll(userPlants);
            } else {
                // Normal case: send to owner
                effectiveRecipients.computeIfAbsent(ownerId, k -> new ArrayList<>()).addAll(userPlants);
            }
        }

        int notificationsSent = 0;

        for (Map.Entry<UUID, List<UserPlantEntity>> entry : effectiveRecipients.entrySet()) {
            UUID recipientId = entry.getKey();
            List<UserPlantEntity> recipientPlants = entry.getValue();

            try {
                sendGroupedReminder(recipientId, recipientPlants);
                notificationsSent++;
            } catch (Exception e) {
                LOG.errorf("Failed to send reminder to user %s: %s", recipientId, e.getMessage());
            }
        }

        LOG.infof("=== Watering reminders complete: %d users notified, %d plants total ===",
                notificationsSent, plantsNeedingWater.size());
    }

    /**
     * Weekly care reminder - runs every Monday at 9:00 AM.
     * Sends personalized care tips based on plant health and species.
     */
    @Scheduled(cron = "${care.reminder.cron:0 0 9 ? * MON}")
    @Transactional
    public void sendWeeklyCareReminders() {
        LOG.info("=== Starting weekly care reminder check ===");

        // Find plants with health issues
        List<UserPlantEntity> sickPlants = UserPlantEntity.list("isSick = true or isWilted = true or needsRepotting = true");

        if (sickPlants.isEmpty()) {
            LOG.info("No plants with care issues found");
            return;
        }

        Map<UUID, List<UserPlantEntity>> plantsByUser = sickPlants.stream()
                .collect(Collectors.groupingBy(p -> p.user.id));

        for (Map.Entry<UUID, List<UserPlantEntity>> entry : plantsByUser.entrySet()) {
            UUID userId = entry.getKey();
            List<UserPlantEntity> userPlants = entry.getValue();

            try {
                sendCareReminder(userId, userPlants);
            } catch (Exception e) {
                LOG.errorf("Failed to send care reminder to user %s: %s", userId, e.getMessage());
            }
        }

        LOG.infof("=== Care reminders complete: %d users with plants needing attention ===", plantsByUser.size());
    }

    /**
     * Send a grouped watering reminder for a user.
     * One notification listing all plants, with personalized tips for each.
     */
    private void sendGroupedReminder(UUID userId, List<UserPlantEntity> plants) {
        // Separate overdue vs due today
        LocalDate today = LocalDate.now();
        List<UserPlantEntity> overdue = new ArrayList<>();
        List<UserPlantEntity> dueToday = new ArrayList<>();

        for (UserPlantEntity plant : plants) {
            if (plant.nextWateringDate != null && plant.nextWateringDate.isBefore(today)) {
                overdue.add(plant);
            } else {
                dueToday.add(plant);
            }
        }

        // Build grouped message
        StringBuilder message = new StringBuilder();

        // Add weather-based advice if available
        try {
            WeatherWateringAdviceDTO weatherAdvice = weatherService.getWateringAdvice(null);
            if (weatherAdvice != null && weatherAdvice.advices() != null && !weatherAdvice.advices().isEmpty()) {
                message.append("🌤️ Météo (").append(weatherAdvice.city()).append("): ");
                message.append(weatherAdvice.advices().get(0)).append("\n\n");
                if (weatherAdvice.shouldSkipOutdoorWatering()) {
                    message.append("☔ Pluie détectée — arrosage extérieur non nécessaire.\n\n");
                }
            }
        } catch (Exception e) {
            LOG.debugf("Weather advice unavailable: %s", e.getMessage());
        }

        if (!overdue.isEmpty()) {
            message.append("⚠️ En retard d'arrosage:\n");
            for (UserPlantEntity plant : overdue) {
                long daysLate = ChronoUnit.DAYS.between(plant.nextWateringDate, today);
                message.append("• ").append(plant.nickname)
                        .append(" (").append(daysLate).append("j de retard)");
                appendCareTip(message, plant);
                message.append("\n");
            }
        }

        if (!dueToday.isEmpty()) {
            if (!overdue.isEmpty()) message.append("\n");
            message.append("💧 A arroser aujourd'hui:\n");
            for (UserPlantEntity plant : dueToday) {
                message.append("• ").append(plant.nickname);
                appendCareTip(message, plant);
                message.append("\n");
            }
        }

        String fullMessage = message.toString().trim();

        // Create in-app notification (linked to first plant for navigation)
        NotificationEntity notification = new NotificationEntity();
        notification.user = UserEntity.findById(userId);
        notification.type = NotificationType.WATERING_REMINDER;
        notification.message = fullMessage;
        if (!plants.isEmpty()) {
            notification.plant = plants.get(0);
        }
        notification.persist();

        // Build push notification title
        String title;
        int total = plants.size();
        if (total == 1) {
            title = "💧 " + plants.get(0).nickname + " a besoin d'eau";
        } else {
            title = "💧 " + total + " plantes a arroser";
        }

        // Build concise push body (FCM has length limits)
        String pushBody = buildPushBody(overdue, dueToday);

        // Send FCM push
        fcmService.sendToUser(userId, title, pushBody,
                Map.of("type", "WATERING_REMINDER",
                        "plantCount", String.valueOf(total),
                        "notificationId", notification.id.toString()));

        LOG.infof("Sent grouped watering reminder to user %s: %d plants (%d overdue, %d today)",
                userId, total, overdue.size(), dueToday.size());
    }

    /**
     * Send a personalized care reminder for plants with health issues.
     */
    private void sendCareReminder(UUID userId, List<UserPlantEntity> plants) {
        StringBuilder message = new StringBuilder("🌱 Vos plantes ont besoin d'attention:\n\n");

        for (UserPlantEntity plant : plants) {
            message.append("• ").append(plant.nickname).append(": ");

            List<String> issues = new ArrayList<>();
            if (plant.isSick) issues.add("malade");
            if (plant.isWilted) issues.add("fanée");
            if (plant.needsRepotting) issues.add("rempotage nécessaire");

            message.append(String.join(", ", issues));

            // Add personalized recommendation based on species
            String recommendation = getPersonalizedRecommendation(plant);
            if (recommendation != null) {
                message.append("\n  → ").append(recommendation);
            }

            message.append("\n");
        }

        String fullMessage = message.toString().trim();

        // Create in-app notification
        NotificationEntity notification = new NotificationEntity();
        notification.user = UserEntity.findById(userId);
        notification.type = NotificationType.CARE_REMINDER;
        notification.message = fullMessage;
        if (!plants.isEmpty()) {
            notification.plant = plants.get(0);
        }
        notification.persist();

        // Send FCM push
        String title = "🌱 " + plants.size() + " plante" + (plants.size() > 1 ? "s" : "") + " nécessite" + (plants.size() > 1 ? "nt" : "") + " attention";
        String pushBody = plants.stream()
                .map(p -> p.nickname)
                .collect(Collectors.joining(", "));

        fcmService.sendToUser(userId, title, pushBody,
                Map.of("type", "CARE_REMINDER",
                        "plantCount", String.valueOf(plants.size()),
                        "notificationId", notification.id.toString()));

        LOG.infof("Sent care reminder to user %s: %d plants with issues", userId, plants.size());
    }

    /**
     * Append a personalized care tip for a plant based on its species.
     */
    private void appendCareTip(StringBuilder message, UserPlantEntity plant) {
        String speciesName = getSpeciesName(plant);
        if (speciesName != null) {
            WateringDefaults.WateringInfo info = WateringDefaults.getFor(speciesName);
            if (WateringDefaults.hasInfoFor(speciesName)) {
                message.append(" - ").append(info.wateringTip());
            }
        }
    }

    /**
     * Get personalized care recommendation based on plant state and species.
     */
    private String getPersonalizedRecommendation(UserPlantEntity plant) {
        List<String> tips = new ArrayList<>();

        String speciesName = getSpeciesName(plant);
        WateringDefaults.WateringInfo info = speciesName != null
                ? WateringDefaults.getFor(speciesName)
                : WateringDefaults.getDefault();

        if (plant.isSick) {
            tips.add("Vérifiez les parasites et isolez la plante si nécessaire");
            if ("tropical".equals(info.category())) {
                tips.add("Les plantes tropicales sont sensibles aux courants d'air froid");
            }
        }

        if (plant.isWilted) {
            if (plant.needsWatering()) {
                tips.add("La plante manque probablement d'eau, arrosez-la en priorité");
            } else {
                tips.add("Si elle est bien arrosée, vérifiez l'exposition (" + info.sunlight() + " recommandé)");
            }
        }

        if (plant.needsRepotting) {
            tips.add("Rempotez dans un pot 2-3cm plus grand avec du terreau frais");
            if ("succulent".equals(info.category())) {
                tips.add("Utilisez un substrat drainant spécial cactées");
            }
        }

        return tips.isEmpty() ? null : String.join(". ", tips);
    }

    /**
     * Build a concise push notification body (FCM has ~4KB limit).
     */
    private String buildPushBody(List<UserPlantEntity> overdue, List<UserPlantEntity> dueToday) {
        StringBuilder body = new StringBuilder();

        if (!overdue.isEmpty()) {
            body.append(overdue.size()).append(" en retard");
            if (overdue.size() <= 3) {
                body.append(": ");
                body.append(overdue.stream()
                        .map(p -> p.nickname)
                        .collect(Collectors.joining(", ")));
            }
        }

        if (!dueToday.isEmpty()) {
            if (!overdue.isEmpty()) body.append(" | ");
            body.append(dueToday.size()).append(" a arroser");
            if (dueToday.size() <= 3) {
                body.append(": ");
                body.append(dueToday.stream()
                        .map(p -> p.nickname)
                        .collect(Collectors.joining(", ")));
            }
        }

        return body.toString();
    }

    /**
     * Get the species name for a plant (from species cache or custom name).
     */
    private String getSpeciesName(UserPlantEntity plant) {
        if (plant.species != null && plant.species.commonName != null) {
            return plant.species.commonName;
        }
        if (plant.customSpecies != null && !plant.customSpecies.isEmpty()) {
            return plant.customSpecies;
        }
        return plant.nickname;
    }
}
