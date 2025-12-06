-- ============================================================================
-- INSERT QUERIES FOR LEARNLYNK ASSESSMENT
-- ============================================================================

-- ============================================================================
-- 1. INSERT LEADS
-- ============================================================================
INSERT INTO leads (tenant_id, name, email, phone, owner_id, stage) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'John Smith', 'john.smith@example.com', '555-0101', '660e8400-e29b-41d4-a716-446655440001', 'lead'),
('550e8400-e29b-41d4-a716-446655440000', 'Sarah Johnson', 'sarah.johnson@example.com', '555-0102', '660e8400-e29b-41d4-a716-446655440001', 'prospect'),
('550e8400-e29b-41d4-a716-446655440000', 'Michael Brown', 'michael.brown@example.com', '555-0103', '660e8400-e29b-41d4-a716-446655440002', 'negotiation'),
('550e8400-e29b-41d4-a716-446655440000', 'Emily Davis', 'emily.davis@example.com', '555-0104', '660e8400-e29b-41d4-a716-446655440001', 'lead'),
('550e8400-e29b-41d4-a716-446655440000', 'James Wilson', 'james.wilson@example.com', '555-0105', '660e8400-e29b-41d4-a716-446655440002', 'customer');

-- ============================================================================
-- 2. INSERT APPLICATIONS
-- ============================================================================
INSERT INTO applications (tenant_id, lead_id, status) VALUES
('550e8400-e29b-41d4-a716-446655440000', 
 (SELECT id FROM leads WHERE email = 'john.smith@example.com' LIMIT 1), 
 'pending'),
('550e8400-e29b-41d4-a716-446655440000', 
 (SELECT id FROM leads WHERE email = 'sarah.johnson@example.com' LIMIT 1), 
 'in_progress'),
('550e8400-e29b-41d4-a716-446655440000', 
 (SELECT id FROM leads WHERE email = 'michael.brown@example.com' LIMIT 1), 
 'approved'),
('550e8400-e29b-41d4-a716-446655440000', 
 (SELECT id FROM leads WHERE email = 'emily.davis@example.com' LIMIT 1), 
 'pending'),
('550e8400-e29b-41d4-a716-446655440000', 
 (SELECT id FROM leads WHERE email = 'james.wilson@example.com' LIMIT 1), 
 'completed');

-- ============================================================================
-- 3. INSERT TASKS
-- ============================================================================
INSERT INTO tasks (tenant_id, application_id, type, status, due_at) VALUES
-- Today's tasks (pending)
('550e8400-e29b-41d4-a716-446655440000',
 (SELECT a.id FROM applications a 
  JOIN leads l ON a.lead_id = l.id 
  WHERE l.email = 'john.smith@example.com' LIMIT 1),
 'call', 'pending', NOW() + INTERVAL '2 hours'),

('550e8400-e29b-41d4-a716-446655440000',
 (SELECT a.id FROM applications a 
  JOIN leads l ON a.lead_id = l.id 
  WHERE l.email = 'sarah.johnson@example.com' LIMIT 1),
 'email', 'pending', NOW() + INTERVAL '4 hours'),

-- Today's tasks (completed)
('550e8400-e29b-41d4-a716-446655440000',
 (SELECT a.id FROM applications a 
  JOIN leads l ON a.lead_id = l.id 
  WHERE l.email = 'michael.brown@example.com' LIMIT 1),
 'review', 'completed', NOW() + INTERVAL '1 hour'),

-- Tomorrow's tasks
('550e8400-e29b-41d4-a716-446655440000',
 (SELECT a.id FROM applications a 
  JOIN leads l ON a.lead_id = l.id 
  WHERE l.email = 'emily.davis@example.com' LIMIT 1),
 'call', 'pending', NOW() + INTERVAL '1 day' + INTERVAL '10 hours'),

-- This week's tasks
('550e8400-e29b-41d4-a716-446655440000',
 (SELECT a.id FROM applications a 
  JOIN leads l ON a.lead_id = l.id 
  WHERE l.email = 'james.wilson@example.com' LIMIT 1),
 'email', 'pending', NOW() + INTERVAL '3 days'),

('550e8400-e29b-41d4-a716-446655440000',
 (SELECT a.id FROM applications a 
  JOIN leads l ON a.lead_id = l.id 
  WHERE l.email = 'john.smith@example.com' LIMIT 1),
 'review', 'cancelled', NOW() + INTERVAL '2 days'),

-- Additional task
('550e8400-e29b-41d4-a716-446655440000',
 (SELECT a.id FROM applications a 
  JOIN leads l ON a.lead_id = l.id 
  WHERE l.email = 'sarah.johnson@example.com' LIMIT 1),
 'call', 'pending', NOW() + INTERVAL '5 days');
