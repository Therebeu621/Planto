-- =====================================================
-- V7: Add Demo Houses with Rooms and Plants
-- =====================================================

-- ==================== HOUSE 1: Appartement Paris ====================
INSERT INTO house (id, name, invite_code) VALUES
    ('33333333-3333-3333-3333-333333333333', 'Appartement Paris', 'PARIS123');

-- User for Appartement Paris (password: "password123")
INSERT INTO app_user (id, house_id, email, password_hash, display_name, role) VALUES
    ('44444444-4444-4444-4444-444444444444',
     '33333333-3333-3333-3333-333333333333',
     'marie@example.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aOQJ1RqQMNMN.wO',
     'Marie Dupont',
     'OWNER');

-- Rooms for Appartement Paris
INSERT INTO room (id, house_id, name, type) VALUES
    ('55555555-5555-5555-5555-555555555551', '33333333-3333-3333-3333-333333333333', 'Salon', 'LIVING_ROOM'),
    ('55555555-5555-5555-5555-555555555552', '33333333-3333-3333-3333-333333333333', 'Cuisine', 'KITCHEN'),
    ('55555555-5555-5555-5555-555555555553', '33333333-3333-3333-3333-333333333333', 'Chambre principale', 'BEDROOM'),
    ('55555555-5555-5555-5555-555555555554', '33333333-3333-3333-3333-333333333333', 'Bureau', 'OFFICE');

-- Plants for Appartement Paris - Salon
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
VALUES
    ('66666666-6666-6666-6666-666666666661', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555551',
     'Ficus Lyrata', 'https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?w=400', 7, 'GOOD', 'PARTIAL_SHADE', 'Grand ficus près de la fenêtre'),
    ('66666666-6666-6666-6666-666666666662', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555551',
     'Pothos', 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=400', 10, 'GOOD', 'SHADE', 'Pothos sur l''étagère');

-- Plants for Appartement Paris - Cuisine
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
VALUES
    ('66666666-6666-6666-6666-666666666663', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555552',
     'Basilic', 'https://images.unsplash.com/photo-1618375569909-3c8616cf7d5f?w=400', 2, 'GOOD', 'SUN', 'Herbes aromatiques'),
    ('66666666-6666-6666-6666-666666666664', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555552',
     'Menthe', 'https://images.unsplash.com/photo-1628556270448-4d4e4148e09e?w=400', 3, 'THIRSTY', 'PARTIAL_SHADE', 'Pour le thé !');

-- Plants for Appartement Paris - Chambre
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
VALUES
    ('66666666-6666-6666-6666-666666666665', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555553',
     'Aloe Vera', 'https://images.unsplash.com/photo-1509423350716-97f9360b4e09?w=400', 14, 'GOOD', 'SUN', 'Plante purifiante');

-- Plants for Appartement Paris - Bureau
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
VALUES
    ('66666666-6666-6666-6666-666666666666', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555554',
     'Sansevieria', 'https://images.unsplash.com/photo-1593691509543-c55fb32e5ce9?w=400', 21, 'GOOD', 'SHADE', 'Langue de belle-mère'),
    ('66666666-6666-6666-6666-666666666667', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555554',
     'Cactus', 'https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?w=400', 30, 'GOOD', 'SUN', 'Petit cactus sur le bureau');


-- ==================== HOUSE 2: Maison Lyon ====================
INSERT INTO house (id, name, invite_code) VALUES
    ('77777777-7777-7777-7777-777777777777', 'Maison Lyon', 'LYON5678');

-- User for Maison Lyon (password: "password123")
INSERT INTO app_user (id, house_id, email, password_hash, display_name, role) VALUES
    ('88888888-8888-8888-8888-888888888888',
     '77777777-7777-7777-7777-777777777777',
     'pierre@example.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aOQJ1RqQMNMN.wO',
     'Pierre Martin',
     'OWNER');

-- Rooms for Maison Lyon
INSERT INTO room (id, house_id, name, type) VALUES
    ('99999999-9999-9999-9999-999999999991', '77777777-7777-7777-7777-777777777777', 'Jardin', 'GARDEN'),
    ('99999999-9999-9999-9999-999999999992', '77777777-7777-7777-7777-777777777777', 'Terrasse', 'BALCONY'),
    ('99999999-9999-9999-9999-999999999993', '77777777-7777-7777-7777-777777777777', 'Serre', 'OTHER'),
    ('99999999-9999-9999-9999-999999999994', '77777777-7777-7777-7777-777777777777', 'Salon', 'LIVING_ROOM');

-- Plants for Maison Lyon - Jardin
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999991',
     'Rosier Rouge', 'https://images.unsplash.com/photo-1518882605630-8996a190c32f?w=400', 3, 'GOOD', 'SUN', 'Rosier magnifique'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee02', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999991',
     'Lavande', 'https://images.unsplash.com/photo-1595351298020-038700609878?w=400', 5, 'GOOD', 'SUN', 'Parfum d''été'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee03', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999991',
     'Tomates cerises', 'https://images.unsplash.com/photo-1592841200221-a6898f307baa?w=400', 1, 'THIRSTY', 'SUN', 'Potager');

-- Plants for Maison Lyon - Terrasse
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee04', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999992',
     'Olivier', 'https://images.unsplash.com/photo-1533167649158-6d508895b680?w=400', 7, 'GOOD', 'SUN', 'Olivier centenaire'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee05', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999992',
     'Géranium', 'https://images.unsplash.com/photo-1598880940952-d7e43cf98d1e?w=400', 4, 'GOOD', 'SUN', 'Géraniums rouges');

-- Plants for Maison Lyon - Serre
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee06', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999993',
     'Orchidée Blanche', 'https://images.unsplash.com/photo-1566907019809-b81e30e8b7a2?w=400', 10, 'GOOD', 'PARTIAL_SHADE', 'Orchidée délicate'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee07', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999993',
     'Bonsaï Ficus', 'https://images.unsplash.com/photo-1567748157439-651aca2ff064?w=400', 5, 'GOOD', 'PARTIAL_SHADE', 'Bonsaï de 15 ans'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee08', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999993',
     'Plante Carnivore', 'https://images.unsplash.com/photo-1509937286353-be0e5f5d30dc?w=400', 2, 'THIRSTY', 'SUN', 'Dionée attrape-mouche');

-- Plants for Maison Lyon - Salon
INSERT INTO user_plant (id, user_id, room_id, nickname, photo_path, watering_interval_days, health_status, exposure, notes)
VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee09', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999994',
     'Monstera Deliciosa', 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=400', 7, 'GOOD', 'PARTIAL_SHADE', 'Monstera géante'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee10', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999994',
     'Palmier d''intérieur', 'https://images.unsplash.com/photo-1598880940080-ff9a29891b85?w=400', 10, 'GOOD', 'SHADE', 'Palmier Areca');
