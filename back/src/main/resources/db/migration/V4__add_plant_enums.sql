-- =====================================================
-- V4: Add Plant Health Status and Exposure Enums
-- =====================================================

-- New ENUMS for plant management
CREATE TYPE health_status AS ENUM ('GOOD', 'THIRSTY', 'SICK');
CREATE TYPE exposure AS ENUM ('SUN', 'SHADE', 'PARTIAL_SHADE');

-- Add columns to user_plant table
ALTER TABLE user_plant ADD COLUMN health_status health_status DEFAULT 'GOOD';
ALTER TABLE user_plant ADD COLUMN exposure exposure DEFAULT 'PARTIAL_SHADE';

-- Index for filtering by health status
CREATE INDEX idx_plant_health_status ON user_plant(health_status);
