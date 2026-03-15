-- Password reset tokens and email verification

ALTER TABLE app_user ADD COLUMN IF NOT EXISTS password_reset_token VARCHAR(255);
ALTER TABLE app_user ADD COLUMN IF NOT EXISTS password_reset_token_expiry TIMESTAMPTZ;
ALTER TABLE app_user ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE app_user ADD COLUMN IF NOT EXISTS email_verification_code VARCHAR(6);
ALTER TABLE app_user ADD COLUMN IF NOT EXISTS email_verification_code_expiry TIMESTAMPTZ;

-- Existing users are considered verified
UPDATE app_user SET email_verified = true WHERE email_verified = false;
