-- =====================================================
-- V4: Test Users for Integration Tests
-- =====================================================

-- Test User 2 (password: "password123") - for multi-user permission tests
INSERT INTO app_user (id, house_id, email, password_hash, display_name, role) VALUES
    ('33333333-3333-3333-3333-333333333333',
     '11111111-1111-1111-1111-111111111111',
     'test2@example.com',
     '$2a$10$rDkPvvAFV8kqwvKJzwlHLOGP.HZqHI.U0C6G5cJVd8d4P3mH6NJem', -- bcrypt hash for "password123"
     'Test User 2',
     'MEMBER');
