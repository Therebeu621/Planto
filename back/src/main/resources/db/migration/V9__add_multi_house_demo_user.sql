-- =====================================================
-- V9: Add Demo User with Multiple Houses
-- =====================================================

-- Multi-house Demo User (password: "password123")
-- This user has access to BOTH "Appartement Paris" and "Maison Lyon"
INSERT INTO app_user (id, house_id, email, password_hash, display_name, role) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     '33333333-3333-3333-3333-333333333333',  -- Default active house: Appartement Paris
     'multi@example.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aOQJ1RqQMNMN.wO',
     'Multi House User',
     'MEMBER');

-- Link this user to Appartement Paris (as active house)
INSERT INTO user_house (user_id, house_id, role, is_active) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
     '33333333-3333-3333-3333-333333333333',  -- Appartement Paris
     'MEMBER', 
     TRUE);

-- Link this user to Maison Lyon (as secondary house)
INSERT INTO user_house (user_id, house_id, role, is_active) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
     '77777777-7777-7777-7777-777777777777',  -- Maison Lyon
     'MEMBER', 
     FALSE);
