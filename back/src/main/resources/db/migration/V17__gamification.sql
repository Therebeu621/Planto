-- Gamification: XP, levels, badges, streaks

-- Badge type enum
CREATE TYPE badge_type AS ENUM (
    'FIRST_WATERING',
    'GREEN_THUMB',
    'COLLECTOR',
    'URBAN_JUNGLE',
    'BOTANIST',
    'CARETAKER',
    'PUNCTUAL',
    'MARATHON',
    'TEAM_PLAYER',
    'GUARDIAN_ANGEL',
    'TROPICAL_EXPERT',
    'CACTUS_KING'
);

-- User gamification profile (XP, level, streak)
CREATE TABLE user_gamification (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES app_user(id) ON DELETE CASCADE,
    xp INTEGER NOT NULL DEFAULT 0,
    level INTEGER NOT NULL DEFAULT 1,
    level_name VARCHAR(50) NOT NULL DEFAULT 'Graine',
    watering_streak INTEGER NOT NULL DEFAULT 0,
    best_watering_streak INTEGER NOT NULL DEFAULT 0,
    total_waterings INTEGER NOT NULL DEFAULT 0,
    total_care_actions INTEGER NOT NULL DEFAULT 0,
    total_plants_added INTEGER NOT NULL DEFAULT 0,
    last_watering_date DATE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- User badges (unlocked achievements)
CREATE TABLE user_badge (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    badge badge_type NOT NULL,
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT uq_user_badge UNIQUE (user_id, badge)
);

-- Indexes
CREATE INDEX idx_user_gamification_user ON user_gamification(user_id);
CREATE INDEX idx_user_gamification_xp ON user_gamification(xp DESC);
CREATE INDEX idx_user_badge_user ON user_badge(user_id);
