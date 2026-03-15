package com.plantmanager.dto;

import com.plantmanager.entity.GardenCultureEntity;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record GardenCultureDTO(
        UUID id,
        String plantName,
        String variety,
        String status,
        String statusDisplay,
        LocalDate sowDate,
        LocalDate expectedHarvestDate,
        LocalDate actualHarvestDate,
        String harvestQuantity,
        String notes,
        Integer rowNumber,
        Integer columnNumber,
        String createdByName,
        OffsetDateTime createdAt,
        List<GrowthLogDTO> growthLogs) {

    public static GardenCultureDTO from(GardenCultureEntity e) {
        return from(e, List.of());
    }

    public static GardenCultureDTO from(GardenCultureEntity e, List<GrowthLogDTO> logs) {
        return new GardenCultureDTO(
                e.id,
                e.plantName,
                e.variety,
                e.status.name(),
                e.status.getDisplayName(),
                e.sowDate,
                e.expectedHarvestDate,
                e.actualHarvestDate,
                e.harvestQuantity,
                e.notes,
                e.rowNumber,
                e.columnNumber,
                e.createdBy != null ? e.createdBy.displayName : null,
                e.createdAt,
                logs);
    }
}
