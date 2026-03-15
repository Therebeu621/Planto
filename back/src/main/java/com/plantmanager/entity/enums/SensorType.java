package com.plantmanager.entity.enums;

public enum SensorType {
    HUMIDITY,
    TEMPERATURE,
    LUMINOSITY,
    SOIL_PH;

    public String getDisplayName() {
        return switch (this) {
            case HUMIDITY -> "Humidite";
            case TEMPERATURE -> "Temperature";
            case LUMINOSITY -> "Luminosite";
            case SOIL_PH -> "pH du sol";
        };
    }

    public String getUnit() {
        return switch (this) {
            case HUMIDITY -> "%";
            case TEMPERATURE -> "°C";
            case LUMINOSITY -> "lux";
            case SOIL_PH -> "pH";
        };
    }
}
