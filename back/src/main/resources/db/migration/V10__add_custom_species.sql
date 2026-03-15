-- V10: Add custom_species column to user_plant table
-- Allows users to enter a custom species name when not selecting from database

ALTER TABLE user_plant ADD COLUMN IF NOT EXISTS custom_species VARCHAR(200);
