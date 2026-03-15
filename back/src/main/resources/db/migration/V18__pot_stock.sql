-- Pot stock management: inventory of pots per house + pot size on plants

-- Table for pot inventory (stock of pots per house)
CREATE TABLE pot_stock (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL REFERENCES house(id) ON DELETE CASCADE,
    diameter_cm NUMERIC(5,1) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    label VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT uq_pot_stock_house_diameter UNIQUE (house_id, diameter_cm)
);

-- Add pot diameter to user_plant
ALTER TABLE user_plant ADD COLUMN pot_diameter_cm NUMERIC(5,1);

-- Indexes
CREATE INDEX idx_pot_stock_house ON pot_stock(house_id);
