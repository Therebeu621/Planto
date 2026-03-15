package com.plantmanager.entity.enums;

/**
 * Types of rooms where plants can be placed.
 * Maps to PostgreSQL enum 'room_type'.
 */
public enum RoomType {
    LIVING_ROOM,
    BEDROOM,
    BALCONY,
    GARDEN,
    KITCHEN,
    BATHROOM,
    OFFICE,
    OTHER
}
