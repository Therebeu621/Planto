package com.plantmanager.entity.enums;

/**
 * Types of care actions that can be performed on plants.
 * Maps to PostgreSQL enum 'care_action'.
 */
public enum CareAction {
    WATERING,
    FERTILIZING,
    REPOTTING,
    PRUNING,
    TREATMENT,
    NOTE
}
