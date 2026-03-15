-- =====================================================
-- V5: Add Demo Plants to Rooms
-- =====================================================

-- First, we need to get the room IDs
-- We'll use fixed UUIDs to make it repeatable

-- Add IDs to existing rooms (update to use fixed UUIDs)
-- Since rooms were created without explicit IDs, we insert new plants linking to rooms by name

-- Demo Plants for Balcon
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
SELECT 
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '22222222-2222-2222-2222-222222222222',
    r.id,
    'Cactus',
    'https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?w=400',
    14,
    'GOOD',
    'SUN',
    'Mon petit cactus résistant'
FROM room r WHERE r.name = 'Balcon' AND r.house_id = '11111111-1111-1111-1111-111111111111';

-- Demo Plants for Chambre
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
SELECT 
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '22222222-2222-2222-2222-222222222222',
    r.id,
    'Ficus',
    'https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?w=400',
    7,
    'GOOD',
    'PARTIAL_SHADE',
    'Ficus dans la chambre'
FROM room r WHERE r.name = 'Chambre' AND r.house_id = '11111111-1111-1111-1111-111111111111';

-- Another plant for Balcon (needs watering)
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, last_watered, notes)
SELECT 
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '22222222-2222-2222-2222-222222222222',
    r.id,
    'Lavande',
    'https://images.unsplash.com/photo-1595351298020-038700609878?w=400',
    5,
    'THIRSTY',
    'SUN',
    NOW() - INTERVAL '10 days',
    'Lavande qui a soif !'
FROM room r WHERE r.name = 'Balcon' AND r.house_id = '11111111-1111-1111-1111-111111111111';

-- Plant for Salon (Monstera)
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, last_watered, notes)
SELECT 
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    '22222222-2222-2222-2222-222222222222',
    r.id,
    'Monstera',
    'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=400',
    7,
    'GOOD',
    'PARTIAL_SHADE',
    NOW() - INTERVAL '2 days',
    'Grande Monstera du salon'
FROM room r WHERE r.name = 'Salon' AND r.house_id = '11111111-1111-1111-1111-111111111111';
