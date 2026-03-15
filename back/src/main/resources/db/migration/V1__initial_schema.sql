-- =====================================================
-- V1: Initial Schema
-- =====================================================

-- Extension requise pour gen_random_uuid() (PostgreSQL < 13)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ENUMS
CREATE TYPE user_role AS ENUM ('OWNER', 'MEMBER');
CREATE TYPE room_type AS ENUM ('LIVING_ROOM', 'BEDROOM', 'BALCONY', 'GARDEN', 'KITCHEN', 'BATHROOM', 'OFFICE', 'OTHER');
CREATE TYPE care_action AS ENUM ('WATERING', 'FERTILIZING', 'REPOTTING', 'PRUNING', 'TREATMENT', 'NOTE');
CREATE TYPE notification_type AS ENUM ('WATERING_REMINDER', 'CARE_REMINDER', 'PLANT_ADDED', 'MEMBER_JOINED');

-- HOUSE
CREATE TABLE house (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    invite_code VARCHAR(8) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- USER
CREATE TABLE app_user (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID REFERENCES house(id) ON DELETE SET NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    role user_role DEFAULT 'MEMBER',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ROOM
CREATE TABLE room (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL REFERENCES house(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    type room_type DEFAULT 'OTHER',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(house_id, name)
);

-- SPECIES CACHE (Trefle.io)
CREATE TABLE species_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trefle_id INTEGER UNIQUE NOT NULL,
    slug VARCHAR(255) UNIQUE,
    common_name VARCHAR(255),
    scientific_name VARCHAR(255),
    family VARCHAR(100),
    genus VARCHAR(100),
    image_url TEXT,
    year INTEGER,
    bibliography TEXT,
    author VARCHAR(255),
    family_common_name VARCHAR(255),
    cached_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    raw_json JSONB
);

-- USER PLANT (My Garden)
CREATE TABLE user_plant (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    room_id UUID REFERENCES room(id) ON DELETE SET NULL,
    species_id UUID REFERENCES species_cache(id),
    nickname VARCHAR(100),
    -- IMPORTANT: Stocker un CHEMIN RELATIF (ex: "plants/abc-123.jpg")
    -- PAS une URL complète! L'URL est construite côté API.
    photo_path TEXT,
    acquired_at DATE DEFAULT CURRENT_DATE,
    last_watered TIMESTAMP WITH TIME ZONE,
    watering_interval_days INTEGER DEFAULT 7,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- CARE LOG
CREATE TABLE care_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plant_id UUID NOT NULL REFERENCES user_plant(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES app_user(id),
    action care_action NOT NULL,
    notes TEXT,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- NOTIFICATION (In-App)
CREATE TABLE notification (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES user_plant(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- INDEXES
CREATE INDEX idx_user_house ON app_user(house_id);
CREATE INDEX idx_user_email ON app_user(email);
CREATE INDEX idx_room_house ON room(house_id);
CREATE INDEX idx_plant_user ON user_plant(user_id);
CREATE INDEX idx_plant_room ON user_plant(room_id);
CREATE INDEX idx_plant_species ON user_plant(species_id);
CREATE INDEX idx_carelog_plant ON care_log(plant_id);
CREATE INDEX idx_carelog_performed ON care_log(performed_at);
CREATE INDEX idx_species_trefle ON species_cache(trefle_id);
CREATE INDEX idx_species_slug ON species_cache(slug);
CREATE INDEX idx_species_common ON species_cache(common_name);
CREATE INDEX idx_notification_user ON notification(user_id);
CREATE INDEX idx_notification_read ON notification(user_id, read);
