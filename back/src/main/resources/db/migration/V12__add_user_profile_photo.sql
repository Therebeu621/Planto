-- =====================================================
-- V12: Add Profile Photo to User
-- =====================================================

-- Add profile photo path column to app_user table (if not exists)
ALTER TABLE app_user ADD COLUMN IF NOT EXISTS profile_photo_path TEXT;

-- Add index for faster lookups (if not exists)
CREATE INDEX IF NOT EXISTS idx_app_user_profile_photo ON app_user(profile_photo_path) WHERE profile_photo_path IS NOT NULL;
