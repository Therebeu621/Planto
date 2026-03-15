-- =====================================================
-- V16: Vacation Mode / Temporary Delegation
-- =====================================================

-- Enum for delegation status
CREATE TYPE vacation_status AS ENUM ('ACTIVE', 'CANCELLED', 'EXPIRED');

-- Vacation delegation table
CREATE TABLE vacation_delegation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL REFERENCES house(id) ON DELETE CASCADE,
    delegator_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    delegate_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status vacation_status NOT NULL DEFAULT 'ACTIVE',
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

    -- Cannot delegate to yourself
    CONSTRAINT chk_no_self_delegation CHECK (delegator_id != delegate_id),
    -- End date must be after start date
    CONSTRAINT chk_dates CHECK (end_date >= start_date)
);

CREATE INDEX idx_vacation_house ON vacation_delegation(house_id);
CREATE INDEX idx_vacation_delegator ON vacation_delegation(delegator_id);
CREATE INDEX idx_vacation_delegate ON vacation_delegation(delegate_id);
CREATE INDEX idx_vacation_active ON vacation_delegation(status) WHERE status = 'ACTIVE';
