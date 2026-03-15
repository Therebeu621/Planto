-- V23: IoT sensor data (Arduino integration)
CREATE TYPE sensor_type AS ENUM ('HUMIDITY', 'TEMPERATURE', 'LUMINOSITY', 'SOIL_PH');

CREATE TABLE iot_sensor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL REFERENCES house(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES user_plant(id) ON DELETE SET NULL,
    sensor_type sensor_type NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    label VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_iot_sensor_house ON iot_sensor(house_id);
CREATE INDEX idx_iot_sensor_plant ON iot_sensor(plant_id);

CREATE TABLE sensor_reading (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sensor_id UUID NOT NULL REFERENCES iot_sensor(id) ON DELETE CASCADE,
    value NUMERIC(10,2) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sensor_reading_sensor ON sensor_reading(sensor_id);
CREATE INDEX idx_sensor_reading_time ON sensor_reading(recorded_at);

-- Alerts when sensor values are out of range
CREATE TABLE sensor_alert (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sensor_id UUID NOT NULL REFERENCES iot_sensor(id) ON DELETE CASCADE,
    min_value NUMERIC(10,2),
    max_value NUMERIC(10,2),
    is_active BOOLEAN DEFAULT TRUE
);
