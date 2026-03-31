package com.plantmanager.entity.enums;

/**
 * Types of notifications sent to users.
 * Maps to PostgreSQL enum 'notification_type'.
 */
public enum NotificationType {
    WATERING_REMINDER,
    CARE_REMINDER,
    PLANT_ADDED,
    MEMBER_JOINED,
    HOUSE_INVITATION
}
