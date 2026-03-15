-- =====================================================
-- V6: Add Multi-House Support (Many-to-Many User <-> House)
-- =====================================================

-- Create junction table for User <-> House relationship
CREATE TABLE user_house (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    house_id UUID NOT NULL REFERENCES house(id) ON DELETE CASCADE,
    role user_role DEFAULT 'MEMBER',
    is_active BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, house_id)
);

-- Create indexes for performance
CREATE INDEX idx_user_house_user ON user_house(user_id);
CREATE INDEX idx_user_house_house ON user_house(house_id);
CREATE INDEX idx_user_house_active ON user_house(user_id, is_active) WHERE is_active = TRUE;

-- Migrate existing user-house relationships to the junction table
INSERT INTO user_house (user_id, house_id, role, is_active, joined_at)
SELECT id, house_id, role, TRUE, created_at
FROM app_user
WHERE house_id IS NOT NULL;

-- Note: We keep the house_id column on app_user for backward compatibility
-- It will be deprecated but not removed immediately
