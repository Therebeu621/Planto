-- =====================================================
-- V8: Add next_watering_date for Performance Optimization
-- =====================================================

-- Add next_watering_date column
ALTER TABLE user_plant ADD COLUMN next_watering_date DATE;

-- Create index for fast queries on plants needing water
CREATE INDEX idx_plant_next_watering ON user_plant(next_watering_date);

-- Initialize next_watering_date for existing plants
-- Formula: last_watered + watering_interval_days (or today + interval if never watered)
UPDATE user_plant 
SET next_watering_date = COALESCE(
    (last_watered::date + (watering_interval_days || ' days')::interval)::date,
    (CURRENT_DATE + (watering_interval_days || ' days')::interval)::date
);

-- Add a comment explaining the column
COMMENT ON COLUMN user_plant.next_watering_date IS 
    'Pre-calculated date when plant needs watering. Updated on watering or interval change.';
