-- Allow duplicate room names in the same house (e.g. multiple "Salon")
ALTER TABLE room DROP CONSTRAINT IF EXISTS room_house_id_name_key;
