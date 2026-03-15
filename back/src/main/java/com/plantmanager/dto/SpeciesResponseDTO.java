package com.plantmanager.dto;

import java.util.UUID;

/**
 * Species response DTO for frontend.
 * Used in search results and plant creation.
 */
public record SpeciesResponseDTO(
    UUID id,
    Integer trefleId,
    String commonName,
    String scientificName,
    String family,
    String genus,
    String imageUrl
) {
}
