package com.plantmanager.service;

import com.plantmanager.client.OpenWeatherClient;
import com.plantmanager.dto.weather.OpenWeatherResponse;
import com.plantmanager.dto.weather.PlantCareSheetDTO;
import com.plantmanager.dto.weather.PlantCareSheetDTO.SeasonalAdvice;
import com.plantmanager.dto.weather.WeatherWateringAdviceDTO;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;

import java.time.LocalDate;
import java.time.Month;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;


/**
 * Service for weather-aware watering intelligence.
 * Integrates OpenWeatherMap data to adjust watering recommendations
 * based on current weather conditions: rain, humidity, temperature.
 */
@ApplicationScoped
public class WeatherService {

    private static final Logger LOG = Logger.getLogger(WeatherService.class);

    @Inject
    @RestClient
    OpenWeatherClient weatherClient;

    @ConfigProperty(name = "openweather.api.key")
    Optional<String> apiKey;

    @ConfigProperty(name = "openweather.default.city", defaultValue = "Paris")
    String defaultCity;

    /**
     * Get current weather for a city.
     * Returns empty if API key not configured or API fails.
     */
    public Optional<OpenWeatherResponse> getCurrentWeather(String city) {
        String key = apiKey.orElse("");
        if (key.isBlank()) {
            LOG.debug("OpenWeather API key not configured, skipping weather check");
            return Optional.empty();
        }

        String targetCity = (city != null && !city.isBlank()) ? city : defaultCity;

        try {
            OpenWeatherResponse response = weatherClient.getCurrentWeather(
                    targetCity, key, "metric", "fr");
            LOG.infof("Weather for %s: %s, %.1f°C, humidity=%d%%",
                    targetCity,
                    response.getWeather() != null && !response.getWeather().isEmpty()
                            ? response.getWeather().get(0).getDescription() : "unknown",
                    response.getMain() != null ? response.getMain().getTemp() : 0,
                    response.getMain() != null ? response.getMain().getHumidity() : 0);
            return Optional.of(response);
        } catch (Exception e) {
            LOG.warnf("Failed to get weather for %s: %s", targetCity, e.getMessage());
            return Optional.empty();
        }
    }

    /**
     * Get weather-based watering advice for a city.
     * Analyzes current conditions and provides intelligent recommendations.
     */
    public WeatherWateringAdviceDTO getWateringAdvice(String city) {
        Optional<OpenWeatherResponse> weatherOpt = getCurrentWeather(city);

        if (weatherOpt.isEmpty()) {
            return buildDefaultAdvice(city);
        }

        OpenWeatherResponse weather = weatherOpt.get();
        List<String> advices = new ArrayList<>();
        boolean shouldSkipOutdoor = false;
        double adjustmentFactor = 1.0;
        String indoorAdvice = "Arrosage normal";

        // === Rain analysis ===
        if (weather.isRaining()) {
            shouldSkipOutdoor = true;
            advices.add("Il pleut actuellement — pas besoin d'arroser les plantes d'extérieur.");
            if (weather.getRainMm() > 5) {
                advices.add("Pluie abondante (%.1f mm) — reportez l'arrosage extérieur de 1-2 jours.".formatted(weather.getRainMm()));
                adjustmentFactor = 1.5;
            }
        }

        // === Humidity analysis ===
        if (weather.isHighHumidity()) {
            advices.add("Humidité élevée (%d%%) — réduisez l'arrosage des plantes tropicales.".formatted(
                    weather.getMain().getHumidity()));
            indoorAdvice = "Réduire l'arrosage (humidité élevée)";
            if (adjustmentFactor == 1.0) adjustmentFactor = 1.3;
        } else if (weather.getMain() != null && weather.getMain().getHumidity() < 30) {
            advices.add("Air très sec (%d%%) — vaporisez les feuilles des plantes tropicales.".formatted(
                    weather.getMain().getHumidity()));
            indoorAdvice = "Augmenter l'arrosage et vaporiser (air sec)";
            adjustmentFactor = 0.8;
        }

        // === Temperature analysis ===
        if (weather.isVeryHot()) {
            advices.add("Canicule (%.1f°C) — arrosez tôt le matin ou tard le soir. Augmentez la fréquence.".formatted(
                    weather.getMain().getTemp()));
            indoorAdvice = "Augmenter la fréquence d'arrosage (chaleur)";
            adjustmentFactor = Math.min(adjustmentFactor, 0.7);
        } else if (weather.isFreezing()) {
            advices.add("Gel (%.1f°C) — réduisez drastiquement l'arrosage. Rentrez les plantes sensibles.".formatted(
                    weather.getMain().getTemp()));
            indoorAdvice = "Réduire l'arrosage (froid)";
            adjustmentFactor = 1.5;
            shouldSkipOutdoor = true;
        }

        // === Wind analysis ===
        if (weather.getWind() != null && weather.getWind().getSpeed() > 30) {
            advices.add("Vent fort (%.0f km/h) — protégez les plantes fragiles.".formatted(weather.getWind().getSpeed()));
        }

        if (advices.isEmpty()) {
            advices.add("Conditions météo normales — suivez votre calendrier d'arrosage habituel.");
        }

        String description = weather.getWeather() != null && !weather.getWeather().isEmpty()
                ? weather.getWeather().get(0).getDescription() : "inconnu";

        return new WeatherWateringAdviceDTO(
                weather.getName() != null ? weather.getName() : (city != null ? city : defaultCity),
                weather.getMain() != null ? weather.getMain().getTemp() : 0,
                weather.getMain() != null ? weather.getMain().getHumidity() : 0,
                description,
                weather.getRainMm(),
                shouldSkipOutdoor,
                indoorAdvice,
                adjustmentFactor,
                advices
        );
    }

    /**
     * Calculate adjusted watering interval based on weather conditions.
     *
     * @param baseIntervalDays the plant's normal watering interval
     * @param city             the city for weather data
     * @return adjusted interval in days (never less than 1, never more than 2x base)
     */
    public int getAdjustedWateringInterval(int baseIntervalDays, String city) {
        WeatherWateringAdviceDTO advice = getWateringAdvice(city);
        double adjusted = baseIntervalDays * advice.intervalAdjustmentFactor();
        return Math.max(1, Math.min((int) Math.round(adjusted), baseIntervalDays * 2));
    }

    /**
     * Generate a complete enriched care sheet for a plant species.
     * Combines local plant knowledge with weather data for comprehensive advice.
     */
    public PlantCareSheetDTO generateCareSheet(String speciesName, String city) {
        WateringDefaults.WateringInfo info = WateringDefaults.getFor(speciesName);
        boolean hasSpecificInfo = WateringDefaults.hasInfoFor(speciesName);

        String category = hasSpecificInfo ? info.category() : "general";
        String categoryLabel = getCategoryLabel(category);

        // Build seasonal advice based on category
        List<SeasonalAdvice> seasonal = buildSeasonalAdvice(category, info.intervalDays());

        // Build common problems based on category
        List<String> problems = buildCommonProblems(category);

        // Get weather advice if available
        String weatherAdvice = null;
        Optional<OpenWeatherResponse> weatherOpt = getCurrentWeather(city);
        if (weatherOpt.isPresent()) {
            weatherAdvice = buildWeatherCareAdvice(weatherOpt.get(), category);
        }

        // Build care summary
        String summary = buildCareSummary(speciesName, info, hasSpecificInfo, categoryLabel);

        return new PlantCareSheetDTO(
                speciesName,
                null, // scientific name would come from PlantDatabaseService
                categoryLabel,
                getWateringFrequencyLabel(info.intervalDays()),
                info.intervalDays(),
                List.of(info.sunlight()),
                getCareLevel(info.intervalDays()),
                info.wateringTip(),
                seasonal,
                problems,
                weatherAdvice,
                summary
        );
    }

    // ===== Private helpers =====

    private WeatherWateringAdviceDTO buildDefaultAdvice(String city) {
        // Seasonal default advice when no weather API is available
        String season = getCurrentSeason();
        List<String> advices = new ArrayList<>();
        double factor = 1.0;

        switch (season) {
            case "summer" -> {
                advices.add("Été — augmentez la fréquence d'arrosage par temps chaud.");
                advices.add("Arrosez tôt le matin ou en fin de journée.");
                factor = 0.8;
            }
            case "winter" -> {
                advices.add("Hiver — réduisez l'arrosage, les plantes sont en repos végétatif.");
                factor = 1.5;
            }
            case "spring" -> {
                advices.add("Printemps — reprise de croissance, augmentez progressivement l'arrosage.");
                factor = 0.9;
            }
            case "autumn" -> {
                advices.add("Automne — réduisez progressivement l'arrosage.");
                factor = 1.2;
            }
        }

        return new WeatherWateringAdviceDTO(
                city != null ? city : defaultCity,
                0, 0, "Données météo non disponibles", 0,
                false, "Arrosage selon la saison (" + season + ")",
                factor, advices
        );
    }

    private List<SeasonalAdvice> buildSeasonalAdvice(String category, int baseInterval) {
        List<SeasonalAdvice> advice = new ArrayList<>();

        switch (category) {
            case "tropical" -> {
                advice.add(new SeasonalAdvice("Printemps", "Augmenter progressivement",
                        "Reprise de croissance, fertiliser toutes les 2 semaines."));
                advice.add(new SeasonalAdvice("Été", "Arrosage fréquent + vaporisation",
                        "Maintenir l'humidité, éloigner du soleil direct."));
                advice.add(new SeasonalAdvice("Automne", "Réduire progressivement",
                        "Stopper la fertilisation, préparer le repos."));
                advice.add(new SeasonalAdvice("Hiver", "Arrosage réduit",
                        "Repos végétatif, éloigner des radiateurs."));
            }
            case "succulent" -> {
                advice.add(new SeasonalAdvice("Printemps", "Reprendre l'arrosage",
                        "Début de croissance, arroser tous les %d jours.".formatted(baseInterval)));
                advice.add(new SeasonalAdvice("Été", "Arrosage normal",
                        "Plein soleil, protéger des brûlures à travers les vitres."));
                advice.add(new SeasonalAdvice("Automne", "Réduire l'arrosage",
                        "Préparer le repos hivernal."));
                advice.add(new SeasonalAdvice("Hiver", "Quasi aucun arrosage",
                        "1 fois par mois maximum, maintenir au frais (5-10°C idéal)."));
            }
            case "flowering" -> {
                advice.add(new SeasonalAdvice("Printemps", "Arrosage régulier",
                        "Période de floraison, fertiliser chaque semaine."));
                advice.add(new SeasonalAdvice("Été", "Arrosage fréquent",
                        "Ne pas laisser sécher, retirer les fleurs fanées."));
                advice.add(new SeasonalAdvice("Automne", "Réduire l'arrosage",
                        "Dernière fertilisation de l'année."));
                advice.add(new SeasonalAdvice("Hiver", "Arrosage minimal",
                        "Repos, tailler si nécessaire."));
            }
            case "herb" -> {
                advice.add(new SeasonalAdvice("Printemps", "Arrosage quotidien",
                        "Semis et repiquage, garder le sol humide."));
                advice.add(new SeasonalAdvice("Été", "Arrosage biquotidien si chaud",
                        "Récolter régulièrement pour stimuler la croissance."));
                advice.add(new SeasonalAdvice("Automne", "Réduire l'arrosage",
                        "Dernières récoltes, rentrer les pots."));
                advice.add(new SeasonalAdvice("Hiver", "Arrosage modéré intérieur",
                        "Cultiver sur rebord de fenêtre, lumière maximale."));
            }
            default -> {
                advice.add(new SeasonalAdvice("Printemps", "Arrosage normal",
                        "Reprise de croissance, fertiliser mensuellement."));
                advice.add(new SeasonalAdvice("Été", "Augmenter l'arrosage",
                        "Surveiller le dessèchement du sol."));
                advice.add(new SeasonalAdvice("Automne", "Réduire l'arrosage",
                        "Préparer le repos hivernal."));
                advice.add(new SeasonalAdvice("Hiver", "Arrosage minimal",
                        "Repos végétatif, moins d'eau."));
            }
        }

        return advice;
    }

    private List<String> buildCommonProblems(String category) {
        List<String> problems = new ArrayList<>();

        // Universal problems
        problems.add("Feuilles jaunes → souvent un excès d'arrosage. Laissez sécher le sol.");
        problems.add("Feuilles qui tombent → stress (changement de lieu, courant d'air, arrosage irrégulier).");

        switch (category) {
            case "tropical" -> {
                problems.add("Bords des feuilles marron → air trop sec, vaporisez régulièrement.");
                problems.add("Taches blanches → cochenilles, nettoyez avec alcool à 70°.");
            }
            case "succulent" -> {
                problems.add("Tige molle → pourriture des racines (trop d'eau). Coupez et bouturez la partie saine.");
                problems.add("Étiolement (tige allongée) → manque de lumière, rapprochez de la fenêtre.");
            }
            case "flowering" -> {
                problems.add("Pas de floraison → manque de lumière ou de nutriments, fertilisez.");
                problems.add("Boutons qui tombent → variation de température ou courant d'air.");
            }
            case "herb" -> {
                problems.add("Feuilles pâles → manque de lumière, déplacez vers une fenêtre ensoleillée.");
                problems.add("Pucerons → vaporisez eau savonneuse ou introduisez des coccinelles.");
            }
            default -> {
                problems.add("Moisissure sur le sol → trop d'humidité, aérez et réduisez l'arrosage.");
                problems.add("Croissance lente → vérifiez lumière, arrosage et rempotez si nécessaire.");
            }
        }

        return problems;
    }

    private String buildWeatherCareAdvice(OpenWeatherResponse weather, String category) {
        StringBuilder advice = new StringBuilder();

        if (weather.isRaining()) {
            advice.append("Pluie détectée — pas d'arrosage extérieur nécessaire. ");
        }

        if (weather.isVeryHot()) {
            if ("tropical".equals(category)) {
                advice.append("Chaleur forte — vaporisez les feuilles et éloignez du soleil direct. ");
            } else if ("succulent".equals(category)) {
                advice.append("Chaleur forte — les succulentes résistent bien, pas de changement. ");
            } else {
                advice.append("Chaleur forte — arrosez plus fréquemment et le soir. ");
            }
        }

        if (weather.isFreezing()) {
            if ("tropical".equals(category)) {
                advice.append("ATTENTION gel — rentrez immédiatement la plante ! ");
            } else if ("succulent".equals(category)) {
                advice.append("Froid — protégez du gel, réduisez l'arrosage au minimum. ");
            } else {
                advice.append("Froid — réduisez l'arrosage, protégez les plantes sensibles. ");
            }
        }

        if (weather.isHighHumidity()) {
            advice.append("Humidité élevée — risque de moisissure, aérez bien. ");
        }

        return advice.isEmpty() ? "Conditions normales, suivez le calendrier habituel." : advice.toString().trim();
    }

    private String buildCareSummary(String speciesName, WateringDefaults.WateringInfo info,
                                     boolean hasSpecificInfo, String categoryLabel) {
        if (hasSpecificInfo) {
            return "Fiche de soin pour %s (%s) : arrosage tous les %d jours, exposition %s. %s".formatted(
                    speciesName, categoryLabel, info.intervalDays(), info.sunlight(), info.wateringTip());
        }
        return "Fiche de soin générique pour %s : arrosage tous les %d jours, exposition %s. Pour des conseils plus précis, identifiez l'espèce exacte.".formatted(
                speciesName, info.intervalDays(), info.sunlight());
    }

    private String getCurrentSeason() {
        Month month = LocalDate.now().getMonth();
        return switch (month) {
            case MARCH, APRIL, MAY -> "spring";
            case JUNE, JULY, AUGUST -> "summer";
            case SEPTEMBER, OCTOBER, NOVEMBER -> "autumn";
            case DECEMBER, JANUARY, FEBRUARY -> "winter";
        };
    }

    private String getCategoryLabel(String category) {
        return switch (category) {
            case "tropical" -> "Tropicale";
            case "succulent" -> "Succulente";
            case "flowering" -> "Floraison";
            case "herb" -> "Herbe aromatique";
            default -> "Plante d'intérieur";
        };
    }

    private String getWateringFrequencyLabel(int intervalDays) {
        if (intervalDays <= 3) return "Fréquent";
        if (intervalDays <= 7) return "Moyen";
        if (intervalDays <= 14) return "Peu fréquent";
        return "Rare";
    }

    private String getCareLevel(int intervalDays) {
        if (intervalDays >= 14) return "Facile";
        if (intervalDays >= 7) return "Moyen";
        return "Attention requise";
    }
}
