package com.plantmanager.dto;

/**
 * DTO for plant search results from local database.
 */
public record PlantSearchResultDTO(
    String nomFrancais,
    String nomLatin,
    int arrosageFrequenceJours,
    String luminosite
) {
}
