package com.plantmanager.entity.enums;

/**
 * Status of a house join request.
 * Maps to PostgreSQL enum 'invitation_status'.
 */
public enum InvitationStatus {
    PENDING,
    ACCEPTED,
    DECLINED
}
