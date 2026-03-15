-- Table to store FCM device tokens for push notifications
CREATE TABLE device_token (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    device_info VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX idx_device_token_user ON device_token(user_id);
CREATE INDEX idx_device_token_token ON device_token(fcm_token);
