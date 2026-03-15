-- V21: Garden cultures (potager) - seeds, growth tracking, harvest
CREATE TYPE culture_status AS ENUM ('SEMIS', 'GERMINATION', 'CROISSANCE', 'FLORAISON', 'RECOLTE', 'TERMINE');

CREATE TABLE garden_culture (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL REFERENCES house(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    plant_name VARCHAR(100) NOT NULL,
    variety VARCHAR(100),
    status culture_status NOT NULL DEFAULT 'SEMIS',
    sow_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_harvest_date DATE,
    actual_harvest_date DATE,
    harvest_quantity VARCHAR(100),
    notes TEXT,
    row_number INTEGER,
    column_number INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_garden_culture_house ON garden_culture(house_id);
CREATE INDEX idx_garden_culture_status ON garden_culture(status);

-- Growth log for tracking progression
CREATE TABLE culture_growth_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    culture_id UUID NOT NULL REFERENCES garden_culture(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES app_user(id),
    old_status culture_status,
    new_status culture_status NOT NULL,
    height_cm NUMERIC(6,1),
    notes TEXT,
    photo_path TEXT,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_culture_growth_log_culture ON culture_growth_log(culture_id);
