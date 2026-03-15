package com.plantmanager.service;

import java.util.Map;
import java.util.HashMap;

/**
 * Default watering and care information for common houseplants.
 * Used when external APIs don't provide care data.
 */
public class WateringDefaults {

    /**
     * Care information for a plant type.
     */
    public record WateringInfo(
            int intervalDays,
            String sunlight, // "Plein soleil", "Mi-ombre", "Ombre"
            String wateringTip, // French care tip
            String category // "tropical", "succulent", "flowering", etc.
    ) {
    }

    private static final WateringInfo DEFAULT = new WateringInfo(7, "Mi-ombre",
            "Arrosage modéré, laisser sécher entre les arrosages", "general");

    private static final Map<String, WateringInfo> DEFAULTS = new HashMap<>();

    static {
        // === TROPICAL (7 days) ===
        DEFAULTS.put("monstera", new WateringInfo(7, "Mi-ombre",
                "Sol humide mais pas détrempé. Vaporiser les feuilles.", "tropical"));
        DEFAULTS.put("pothos", new WateringInfo(7, "Ombre à mi-ombre",
                "Très facile, tolère la sécheresse.", "tropical"));
        DEFAULTS.put("philodendron", new WateringInfo(7, "Mi-ombre",
                "Garder le sol légèrement humide.", "tropical"));
        DEFAULTS.put("calathea", new WateringInfo(5, "Ombre",
                "Sol toujours humide, eau non calcaire.", "tropical"));
        DEFAULTS.put("fougere", new WateringInfo(5, "Ombre",
                "Aime l'humidité, vaporiser régulièrement.", "tropical"));
        DEFAULTS.put("fern", new WateringInfo(5, "Ombre",
                "Aime l'humidité, vaporiser régulièrement.", "tropical"));
        DEFAULTS.put("dracaena", new WateringInfo(10, "Mi-ombre",
                "Laisser sécher le dessus du sol.", "tropical"));
        DEFAULTS.put("palmier", new WateringInfo(7, "Mi-ombre",
                "Sol humide mais bien drainé.", "tropical"));
        DEFAULTS.put("palm", new WateringInfo(7, "Mi-ombre",
                "Sol humide mais bien drainé.", "tropical"));
        DEFAULTS.put("spathiphyllum", new WateringInfo(7, "Ombre",
                "Sol toujours légèrement humide.", "tropical"));
        DEFAULTS.put("peace lily", new WateringInfo(7, "Ombre",
                "Sol toujours légèrement humide.", "tropical"));
        DEFAULTS.put("anthurium", new WateringInfo(7, "Mi-ombre",
                "Sol humide, éviter l'eau stagnante.", "tropical"));

        // === SUCCULENTS (14-21 days) ===
        DEFAULTS.put("cactus", new WateringInfo(21, "Plein soleil",
                "Laisser sécher complètement entre les arrosages.", "succulent"));
        DEFAULTS.put("aloe", new WateringInfo(14, "Plein soleil",
                "Arrosage rare, éviter l'excès d'eau.", "succulent"));
        DEFAULTS.put("succulent", new WateringInfo(14, "Plein soleil",
                "Sol bien drainé, peu d'eau.", "succulent"));
        DEFAULTS.put("echeveria", new WateringInfo(14, "Plein soleil",
                "Arroser quand le sol est sec.", "succulent"));
        DEFAULTS.put("haworthia", new WateringInfo(14, "Mi-ombre",
                "Tolère l'ombre, arrosage rare.", "succulent"));
        DEFAULTS.put("crassula", new WateringInfo(14, "Plein soleil",
                "Laisser sécher entre les arrosages.", "succulent"));
        DEFAULTS.put("jade", new WateringInfo(14, "Plein soleil",
                "Arrosage modéré, sol bien drainé.", "succulent"));
        DEFAULTS.put("sansevieria", new WateringInfo(21, "Mi-ombre",
                "Très résistant, arrosage rare.", "succulent"));
        DEFAULTS.put("snake plant", new WateringInfo(21, "Mi-ombre",
                "Très résistant, arrosage rare.", "succulent"));

        // === FLOWERING (5-7 days) ===
        DEFAULTS.put("orchid", new WateringInfo(10, "Mi-ombre",
                "Tremper le pot 10min, bien égoutter.", "flowering"));
        DEFAULTS.put("orchidee", new WateringInfo(10, "Mi-ombre",
                "Tremper le pot 10min, bien égoutter.", "flowering"));
        DEFAULTS.put("rose", new WateringInfo(3, "Plein soleil",
                "Sol toujours humide, éviter les feuilles.", "flowering"));
        DEFAULTS.put("begonia", new WateringInfo(5, "Mi-ombre",
                "Sol humide mais pas détrempé.", "flowering"));
        DEFAULTS.put("geranium", new WateringInfo(5, "Plein soleil",
                "Arrosage régulier en été.", "flowering"));
        DEFAULTS.put("hibiscus", new WateringInfo(5, "Plein soleil",
                "Sol toujours humide en été.", "flowering"));
        DEFAULTS.put("jasmin", new WateringInfo(5, "Plein soleil",
                "Arrosage régulier pendant la floraison.", "flowering"));
        DEFAULTS.put("lavande", new WateringInfo(10, "Plein soleil",
                "Sol sec, résistant à la sécheresse.", "flowering"));
        DEFAULTS.put("lavender", new WateringInfo(10, "Plein soleil",
                "Sol sec, résistant à la sécheresse.", "flowering"));

        // === COMMON HOUSEPLANTS ===
        DEFAULTS.put("ficus", new WateringInfo(10, "Mi-ombre",
                "Laisser sécher entre les arrosages, éviter les courants d'air.", "general"));
        DEFAULTS.put("yucca", new WateringInfo(14, "Plein soleil",
                "Résistant à la sécheresse.", "general"));
        DEFAULTS.put("caoutchouc", new WateringInfo(10, "Mi-ombre",
                "Arrosage modéré, essuyer les feuilles.", "general"));
        DEFAULTS.put("rubber", new WateringInfo(10, "Mi-ombre",
                "Arrosage modéré, essuyer les feuilles.", "general"));
        DEFAULTS.put("croton", new WateringInfo(7, "Mi-ombre",
                "Sol humide, bonne luminosité pour les couleurs.", "general"));
        DEFAULTS.put("dieffenbachia", new WateringInfo(7, "Mi-ombre",
                "Sol légèrement humide.", "general"));
        DEFAULTS.put("schefflera", new WateringInfo(10, "Mi-ombre",
                "Laisser sécher le dessus du sol.", "general"));
        DEFAULTS.put("zamioculcas", new WateringInfo(21, "Ombre",
                "Très résistant, arrosage rare.", "general"));
        DEFAULTS.put("zz plant", new WateringInfo(21, "Ombre",
                "Très résistant, arrosage rare.", "general"));

        // === HERBS (2-3 days) ===
        DEFAULTS.put("basilic", new WateringInfo(2, "Plein soleil",
                "Sol toujours humide.", "herb"));
        DEFAULTS.put("basil", new WateringInfo(2, "Plein soleil",
                "Sol toujours humide.", "herb"));
        DEFAULTS.put("menthe", new WateringInfo(2, "Mi-ombre",
                "Sol humide en permanence.", "herb"));
        DEFAULTS.put("mint", new WateringInfo(2, "Mi-ombre",
                "Sol humide en permanence.", "herb"));
        DEFAULTS.put("persil", new WateringInfo(3, "Mi-ombre",
                "Sol humide.", "herb"));
        DEFAULTS.put("parsley", new WateringInfo(3, "Mi-ombre",
                "Sol humide.", "herb"));
        DEFAULTS.put("thym", new WateringInfo(7, "Plein soleil",
                "Sol sec entre les arrosages.", "herb"));
        DEFAULTS.put("thyme", new WateringInfo(7, "Plein soleil",
                "Sol sec entre les arrosages.", "herb"));
        DEFAULTS.put("romarin", new WateringInfo(10, "Plein soleil",
                "Résistant à la sécheresse.", "herb"));
        DEFAULTS.put("rosemary", new WateringInfo(10, "Plein soleil",
                "Résistant à la sécheresse.", "herb"));
    }

    /**
     * Get watering info for a plant name.
     * Checks if any keyword is contained in the plant name.
     */
    public static WateringInfo getFor(String plantName) {
        if (plantName == null || plantName.isBlank()) {
            return DEFAULT;
        }

        String lower = plantName.toLowerCase().trim();

        // Check exact match first
        if (DEFAULTS.containsKey(lower)) {
            return DEFAULTS.get(lower);
        }

        // Check if any keyword is contained in the name
        for (var entry : DEFAULTS.entrySet()) {
            if (lower.contains(entry.getKey())) {
                return entry.getValue();
            }
        }

        return DEFAULT;
    }

    /**
     * Get default info when no match found.
     */
    public static WateringInfo getDefault() {
        return DEFAULT;
    }

    /**
     * Check if we have specific info for this plant.
     */
    public static boolean hasInfoFor(String plantName) {
        if (plantName == null || plantName.isBlank()) {
            return false;
        }
        String lower = plantName.toLowerCase().trim();
        if (DEFAULTS.containsKey(lower))
            return true;
        for (String key : DEFAULTS.keySet()) {
            if (lower.contains(key))
                return true;
        }
        return false;
    }
}
