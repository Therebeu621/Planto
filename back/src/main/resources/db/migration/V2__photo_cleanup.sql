-- =====================================================
-- V2: Photo Cleanup Strategy
-- =====================================================

-- Table de queue pour nettoyage asynchrone des photos
CREATE TABLE photo_cleanup_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_path TEXT NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour le job de nettoyage
CREATE INDEX idx_photo_cleanup_deleted ON photo_cleanup_queue(deleted_at);

-- Trigger pour marquer les photos à supprimer quand une plante est supprimée
CREATE OR REPLACE FUNCTION queue_photo_for_deletion()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.photo_path IS NOT NULL THEN
        INSERT INTO photo_cleanup_queue (photo_path, deleted_at)
        VALUES (OLD.photo_path, NOW());
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER plant_photo_cleanup
AFTER DELETE ON user_plant
FOR EACH ROW
EXECUTE FUNCTION queue_photo_for_deletion();
