-- ============================================================================
-- SAMPLE DATA FOR RLS TESTING
-- ============================================================================

-- Tenant ID (use the same one from leads)
-- 550e8400-e29b-41d4-a716-446655440000

-- ============================================================================
-- 1. INSERT SAMPLE USERS
-- ============================================================================
INSERT INTO users (id, tenant_id, email, name, role) VALUES
-- Admin user
('660e8400-e29b-41d4-a716-446655440099', '550e8400-e29b-41d4-a716-446655440000', 'admin@example.com', 'Admin User', 'admin'),

-- Counselor users
('660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440000', 'counselor1@example.com', 'Counselor One', 'counselor'),
('660e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440000', 'counselor2@example.com', 'Counselor Two', 'counselor'),
('660e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440000', 'counselor3@example.com', 'Counselor Three', 'counselor'),

-- Viewer user
('660e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440000', 'viewer@example.com', 'Viewer User', 'viewer');

-- ============================================================================
-- 2. INSERT SAMPLE TEAMS
-- ============================================================================
INSERT INTO teams (id, tenant_id, name) VALUES
('770e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440000', 'Sales Team'),
('770e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440000', 'Support Team');

-- ============================================================================
-- 3. INSERT USER-TEAM ASSIGNMENTS
-- ============================================================================
INSERT INTO user_teams (user_id, team_id) VALUES
-- Counselor 1 and 2 in Sales Team
('660e8400-e29b-41d4-a716-446655440001', '770e8400-e29b-41d4-a716-446655440001'),
('660e8400-e29b-41d4-a716-446655440002', '770e8400-e29b-41d4-a716-446655440001'),

-- Counselor 2 and 3 in Support Team
('660e8400-e29b-41d4-a716-446655440002', '770e8400-e29b-41d4-a716-446655440002'),
('660e8400-e29b-41d4-a716-446655440003', '770e8400-e29b-41d4-a716-446655440002');

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
SELECT 'Users' as entity, COUNT(*) as count FROM users;
SELECT 'Teams' as entity, COUNT(*) as count FROM teams;
SELECT 'User-Team Assignments' as entity, COUNT(*) as count FROM user_teams;

-- View user details
SELECT id, email, name, role FROM users ORDER BY role;

-- View team details
SELECT id, name FROM teams;

-- View team memberships
SELECT u.email as user_email, t.name as team_name 
FROM user_teams ut
JOIN users u ON ut.user_id = u.id
JOIN teams t ON ut.team_id = t.id
ORDER BY t.name, u.email;
