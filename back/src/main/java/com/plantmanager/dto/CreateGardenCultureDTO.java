package com.plantmanager.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record CreateGardenCultureDTO(
        @NotBlank(message = "Plant name is required")
        @Size(max = 100)
        String plantName,

        @Size(max = 100)
        String variety,

        LocalDate sowDate,
        LocalDate expectedHarvestDate,
        String notes,
        Integer rowNumber,
        Integer columnNumber) {
}
