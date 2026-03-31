-- =====================================================
-- V24: House Invitation System (demande d'adhésion)
-- =====================================================

-- Enum pour le statut de l'invitation
CREATE TYPE invitation_status AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED');

-- Ajouter HOUSE_INVITATION au type notification_type
ALTER TYPE notification_type ADD VALUE 'HOUSE_INVITATION';

-- Table des demandes d'adhésion
CREATE TABLE house_invitation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL REFERENCES house(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    status invitation_status NOT NULL DEFAULT 'PENDING',
    responded_by UUID REFERENCES app_user(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(house_id, requester_id, status)
);

-- Ajouter une colonne invitation_id dans notification pour lier la notif à l'invitation
ALTER TABLE notification ADD COLUMN invitation_id UUID REFERENCES house_invitation(id) ON DELETE CASCADE;
ALTER TABLE notification ADD COLUMN house_id UUID REFERENCES house(id) ON DELETE CASCADE;

-- Indexes
CREATE INDEX idx_invitation_house ON house_invitation(house_id);
CREATE INDEX idx_invitation_requester ON house_invitation(requester_id);
CREATE INDEX idx_invitation_status ON house_invitation(house_id, status);
CREATE INDEX idx_notification_invitation ON notification(invitation_id);
