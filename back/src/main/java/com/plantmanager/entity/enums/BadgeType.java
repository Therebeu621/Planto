package com.plantmanager.entity.enums;

/**
 * Types of badges that can be unlocked.
 * Maps to PostgreSQL enum 'badge_type'.
 */
public enum BadgeType {
    FIRST_WATERING("Premier Arrosage", "Arroser sa premiere plante", "watering", "first_watering"),
    GREEN_THUMB("Main Verte", "50 arrosages", "watering", "green_thumb"),
    COLLECTOR("Collectionneur", "5 plantes dans son jardin", Categories.COLLECTION, "collector"),
    URBAN_JUNGLE("Jungle Urbaine", "15 plantes dans son jardin", Categories.COLLECTION, "urban_jungle"),
    BOTANIST("Botaniste", "5 especes differentes", Categories.COLLECTION, "botanist"),
    CARETAKER("Soigneur", "10 soins (fertilisation, taille, etc.)", "care", "caretaker"),
    PUNCTUAL("Ponctuel", "7 jours sans retard d'arrosage", "streak", "punctual"),
    MARATHON("Marathonien", "30 jours sans retard d'arrosage", "streak", "marathon"),
    TEAM_PLAYER("Equipier", "Rejoindre une maison avec 2+ membres", "social", "team_player"),
    GUARDIAN_ANGEL("Ange Gardien", "Accepter une delegation vacances", "social", "guardian_angel"),
    TROPICAL_EXPERT("Expert Tropical", "3 plantes tropicales", "specialist", "tropical_expert"),
    CACTUS_KING("Roi des Cactus", "3 cactees ou succulentes", "specialist", "cactus_king");

    private static final class Categories {
        static final String COLLECTION = "collection";
    }

    private final String displayName;
    private final String description;
    private final String category;
    private final String icon;

    BadgeType(String displayName, String description, String category, String icon) {
        this.displayName = displayName;
        this.description = description;
        this.category = category;
        this.icon = icon;
    }

    public String getDisplayName() { return displayName; }
    public String getDescription() { return description; }
    public String getCategory() { return category; }
    public String getIconUrl() { return "/api/v1/badges/" + icon + ".png"; }
}
