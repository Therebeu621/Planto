package com.plantmanager.entity.enums;

public enum CultureStatus {
    SEMIS,
    GERMINATION,
    CROISSANCE,
    FLORAISON,
    RECOLTE,
    TERMINE;

    public String getDisplayName() {
        return switch (this) {
            case SEMIS -> "Semis";
            case GERMINATION -> "Germination";
            case CROISSANCE -> "Croissance";
            case FLORAISON -> "Floraison";
            case RECOLTE -> "Recolte";
            case TERMINE -> "Termine";
        };
    }
}
