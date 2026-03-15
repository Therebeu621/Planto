-- =====================================================
-- V11: Refactor Health Status to Boolean Flags
-- =====================================================

-- 1. Add new boolean columns with default false
ALTER TABLE user_plant ADD COLUMN is_sick BOOLEAN DEFAULT FALSE;
ALTER TABLE user_plant ADD COLUMN is_wilted BOOLEAN DEFAULT FALSE;
ALTER TABLE user_plant ADD COLUMN needs_repotting BOOLEAN DEFAULT FALSE;

-- 2. Migrate existing data (attempt to map enum to booleans)
UPDATE user_plant SET is_sick = TRUE WHERE health_status = 'SICK';
-- Note: THIRSTY is handled dynamically via next_watering_date, so no boolean needed.
-- Note: GOOD means all booleans are false.

-- 3. Drop the old enum column
ALTER TABLE user_plant DROP COLUMN health_status;

-- 4. Drop the enum type if it exists and is no longer used
DROP TYPE IF EXISTS health_status;
