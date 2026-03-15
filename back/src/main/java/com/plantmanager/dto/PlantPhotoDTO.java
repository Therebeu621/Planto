package com.plantmanager.dto;

import com.plantmanager.entity.PlantPhotoEntity;

import java.time.OffsetDateTime;
import java.util.UUID;

public record PlantPhotoDTO(
        UUID id,
        String photoUrl,
        String caption,
        boolean isPrimary,
        String uploadedByName,
        OffsetDateTime uploadedAt) {

    public static PlantPhotoDTO from(PlantPhotoEntity e) {
        return from(e, "/api/v1/files");
    }

    public static PlantPhotoDTO from(PlantPhotoEntity e, String baseUrl) {
        String url = e.photoPath;
        if (url != null && !url.startsWith("http")) {
            url = baseUrl + "/" + url;
        }
        return new PlantPhotoDTO(
                e.id,
                url,
                e.caption,
                e.isPrimary,
                e.uploadedBy != null ? e.uploadedBy.displayName : null,
                e.uploadedAt);
    }
}
