-- =====================================================
-- V3: Seed Data for Development
-- =====================================================

-- Demo House
INSERT INTO house (id, name, invite_code) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Demo House', 'DEMO1234');

-- Demo User (password: "password123")
INSERT INTO app_user (id, house_id, email, password_hash, display_name, role) VALUES
    ('22222222-2222-2222-2222-222222222222',
     '11111111-1111-1111-1111-111111111111',
     'demo@example.com',
     '$2a$10$rDkPvvAFV8kqwvKJzwlHLOGP.HZqHI.U0C6G5cJVd8d4P3mH6NJem', -- bcrypt hash for "password123"
     'Demo User',
     'OWNER');

-- MCP System User (OBLIGATOIRE pour la démo MCP/Goose)
-- Ce compte est utilisé par l'endpoint /mcp/tools
-- L'UUID doit correspondre à MCP_SYSTEM_USER_ID dans la config
INSERT INTO app_user (id, house_id, email, password_hash, display_name, role) VALUES
    ('00000000-0000-0000-0000-000000000001',
     '11111111-1111-1111-1111-111111111111',
     'mcp-system@plant-management.local',
     '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQlB0N3cLgBxWfgq3vXo0XQK0Kuu', -- pas utilisé pour login
     'MCP System',
     'OWNER');

-- Demo Rooms
INSERT INTO room (house_id, name, type) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Salon', 'LIVING_ROOM'),
    ('11111111-1111-1111-1111-111111111111', 'Balcon', 'BALCONY'),
    ('11111111-1111-1111-1111-111111111111', 'Chambre', 'BEDROOM');
