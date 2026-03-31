-- =====================================================
-- V25: Comptes de demo pour la presentation
-- 3 comptes: Cyrille (avec data), + 2 comptes vides
-- Mot de passe pour tous: password123
-- =====================================================

-- ==================== COMPTE 1: Cyrille Arthur Gautier (riche en data) ====================

-- User Cyrille
INSERT INTO app_user (id, email, password_hash, display_name, role, email_verified) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'cyrille@example.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aOQJ1RqQMNMN.wO',
     'Cyrille Arthur Gautier',
     'OWNER',
     true);

-- Maison 1: Appartement Lille
INSERT INTO house (id, name, invite_code) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa010', 'Appartement Lille', 'LILLE026');

-- Lier Cyrille a Maison 1 (active)
INSERT INTO user_house (id, user_id, house_id, role, is_active) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa020',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa010',
     'OWNER', true);

-- Pieces Maison 1
INSERT INTO room (id, house_id, name, type) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa031', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa010', 'Salon', 'LIVING_ROOM'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa032', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa010', 'Chambre', 'BEDROOM'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa033', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa010', 'Cuisine', 'KITCHEN'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa034', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa010', 'Balcon', 'BALCONY');

-- Plantes Maison 1
INSERT INTO user_plant (id, user_id, room_id, nickname, custom_species, watering_interval_days, exposure, last_watered, next_watering_date, notes, is_sick, is_wilted, needs_repotting, photo_path) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa041',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa031',
     'Mon Pothos Dore', 'Epipremnum aureum', 7, 'PARTIAL_SHADE',
     NOW() - INTERVAL '2 days', CURRENT_DATE + 5,
     'Pousse super bien pres de la fenetre', false, false, false,
     'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa042',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa031',
     'Ficus Robusta', 'Ficus elastica', 10, 'SUN',
     NOW() - INTERVAL '8 days', CURRENT_DATE + 2,
     'Feuilles brillantes', false, false, false,
     'https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa043',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa032',
     'Orchidee Blanche', 'Phalaenopsis', 12, 'PARTIAL_SHADE',
     NOW() - INTERVAL '5 days', CURRENT_DATE + 7,
     'Offerte pour mon anniversaire', false, false, false,
     'https://images.unsplash.com/photo-1566907019809-b81e30e8b7a2?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa044',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa032',
     'Aloe Vera', 'Aloe barbadensis', 14, 'SUN',
     NOW() - INTERVAL '10 days', CURRENT_DATE + 4,
     'Utile pour les brulures', false, false, false,
     'https://images.unsplash.com/photo-1509423350716-97f9360b4e09?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa045',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa033',
     'Basilic', 'Ocimum basilicum', 2, 'SUN',
     NOW() - INTERVAL '3 days', CURRENT_DATE - 1,
     'Pour la cuisine !', false, false, false,
     'https://images.unsplash.com/photo-1618375569909-3c8616cf7d5f?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa046',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa033',
     'Menthe', 'Mentha spicata', 3, 'PARTIAL_SHADE',
     NOW() - INTERVAL '4 days', CURRENT_DATE - 1,
     'Pour le the a la menthe', false, false, false,
     'https://images.unsplash.com/photo-1628556270448-4d4e4148e09e?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa047',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa034',
     'Geranium Rouge', 'Pelargonium', 4, 'SUN',
     NOW() - INTERVAL '1 day', CURRENT_DATE + 3,
     'Magnifique sur le balcon', false, false, false,
     'https://images.unsplash.com/photo-1598880940952-d7e43cf98d1e?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa048',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa034',
     'Lavande', 'Lavandula angustifolia', 7, 'SUN',
     NOW() - INTERVAL '6 days', CURRENT_DATE + 1,
     'Sent super bon', false, false, false,
     'https://images.unsplash.com/photo-1595351298020-038700609878?w=400');

-- Quelques soins recents pour Cyrille
INSERT INTO care_log (id, plant_id, user_id, action, performed_at, notes) VALUES
    (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa041', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', 'WATERING', NOW() - INTERVAL '2 days', 'Arrosage normal'),
    (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa041', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', 'WATERING', NOW() - INTERVAL '9 days', NULL),
    (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa042', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', 'WATERING', NOW() - INTERVAL '8 days', NULL),
    (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa042', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', 'FERTILIZING', NOW() - INTERVAL '15 days', 'Engrais liquide'),
    (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa045', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', 'WATERING', NOW() - INTERVAL '3 days', NULL),
    (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa047', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', 'PRUNING', NOW() - INTERVAL '7 days', 'Taille des fleurs fanees');

-- Maison 2: Maison de Campagne
INSERT INTO house (id, name, invite_code) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa011', 'Maison de Campagne', 'CAMP026');

-- Lier Cyrille a Maison 2 (inactive)
INSERT INTO user_house (id, user_id, house_id, role, is_active) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa021',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa011',
     'OWNER', false);

-- Pieces Maison 2
INSERT INTO room (id, house_id, name, type) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa035', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa011', 'Jardin', 'GARDEN'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa036', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa011', 'Veranda', 'OTHER');

-- Plantes Maison 2
INSERT INTO user_plant (id, user_id, room_id, nickname, custom_species, watering_interval_days, exposure, last_watered, next_watering_date, notes, is_sick, is_wilted, needs_repotting, photo_path) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa051',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa035',
     'Rosier Grimpant', 'Rosa', 3, 'SUN',
     NOW() - INTERVAL '2 days', CURRENT_DATE + 1,
     'Le long du mur', false, false, false,
     'https://images.unsplash.com/photo-1518882605630-8996a190c32f?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa052',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa035',
     'Olivier', 'Olea europaea', 10, 'SUN',
     NOW() - INTERVAL '5 days', CURRENT_DATE + 5,
     'Centenaire', false, false, false,
     'https://images.unsplash.com/photo-1533167649158-6d508895b680?w=400'),

    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa053',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa036',
     'Bonsai Ficus', 'Ficus retusa', 5, 'PARTIAL_SHADE',
     NOW() - INTERVAL '3 days', CURRENT_DATE + 2,
     'Mon petit bonsai', false, false, false,
     'https://images.unsplash.com/photo-1567748157439-651aca2ff064?w=400');


-- ==================== COMPTE 2: Lucas Moreau (vide) ====================
INSERT INTO app_user (id, email, password_hash, display_name, role, email_verified) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa002',
     'lucas.m@example.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aOQJ1RqQMNMN.wO',
     'Lucas Moreau',
     'MEMBER',
     true);

-- Maison vide pour Lucas
INSERT INTO house (id, name, invite_code) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa012', 'Chez Lucas', 'LUCAS26');

INSERT INTO user_house (id, user_id, house_id, role, is_active) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa022',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa002',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa012',
     'OWNER', true);


-- ==================== COMPTE 3: Emma Petit (vide) ====================
INSERT INTO app_user (id, email, password_hash, display_name, role, email_verified) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003',
     'emma@example.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aOQJ1RqQMNMN.wO',
     'Emma Petit',
     'MEMBER',
     true);

-- Maison vide pour Emma
INSERT INTO house (id, name, invite_code) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa013', 'Chez Emma', 'EMMA2026');

INSERT INTO user_house (id, user_id, house_id, role, is_active) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa023',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa013',
     'OWNER', true);
