package com.plantmanager.dto;

import com.plantmanager.entity.VacationDelegationEntity;
import com.plantmanager.entity.enums.VacationStatus;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO for vacation delegation response.
 */
public record VacationResponseDTO(
        UUID id,
        UUID houseId,
        UUID delegatorId,
        String delegatorName,
        UUID delegateId,
        String delegateName,
        LocalDate startDate,
        LocalDate endDate,
        VacationStatus status,
        String message,
        OffsetDateTime createdAt) {

    public static VacationResponseDTO from(VacationDelegationEntity entity) {
        return new VacationResponseDTO(
                entity.id,
                entity.house.id,
                entity.delegator.id,
                entity.delegator.displayName,
                entity.delegate.id,
                entity.delegate.displayName,
                entity.startDate,
                entity.endDate,
                entity.status,
                entity.message,
                entity.createdAt);
    }
}
