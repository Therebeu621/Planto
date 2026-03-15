-- V22: Multi-photo gallery for plants
CREATE TABLE plant_photo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plant_id UUID NOT NULL REFERENCES user_plant(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES app_user(id),
    photo_path TEXT NOT NULL,
    caption VARCHAR(200),
    is_primary BOOLEAN DEFAULT FALSE,
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_plant_photo_plant ON plant_photo(plant_id);

-- Migrate existing photos: if a plant has a photo_path, insert it into gallery as primary
INSERT INTO plant_photo (plant_id, uploaded_by, photo_path, is_primary)
SELECT up.id, up.user_id, up.photo_path, true
FROM user_plant up
WHERE up.photo_path IS NOT NULL AND up.photo_path != '';
