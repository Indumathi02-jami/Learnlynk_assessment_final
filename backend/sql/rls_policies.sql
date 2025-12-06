-- ============================================================================
-- ROW-LEVEL SECURITY (RLS) SETUP
-- ============================================================================
-- This file sets up the users, teams, and user_teams tables
-- and implements RLS policies for the leads table

-- ============================================================================
-- 1. CREATE SUPPORTING TABLES
-- ============================================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'counselor', 'viewer')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, email)
);

-- Teams table
CREATE TABLE IF NOT EXISTS teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User-Teams association table (many-to-many)
CREATE TABLE IF NOT EXISTS user_teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, team_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_teams_tenant_id ON teams(tenant_id);
CREATE INDEX IF NOT EXISTS idx_user_teams_user_id ON user_teams(user_id);
CREATE INDEX IF NOT EXISTS idx_user_teams_team_id ON user_teams(team_id);

-- ============================================================================
-- 2. ENABLE ROW-LEVEL SECURITY
-- ============================================================================

-- Enable RLS on leads table
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- Enable RLS on applications table
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- Enable RLS on tasks table
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for reapplication)
DROP POLICY IF EXISTS leads_select_policy ON leads;
DROP POLICY IF EXISTS leads_insert_policy ON leads;
DROP POLICY IF EXISTS leads_update_policy ON leads;
DROP POLICY IF EXISTS leads_delete_policy ON leads;
DROP POLICY IF EXISTS applications_select_policy ON applications;
DROP POLICY IF EXISTS applications_insert_policy ON applications;
DROP POLICY IF EXISTS tasks_select_policy ON tasks;
DROP POLICY IF EXISTS tasks_insert_policy ON tasks;
DROP POLICY IF EXISTS tasks_update_policy ON tasks;
DROP POLICY IF EXISTS tasks_delete_policy ON tasks;

-- ============================================================================
-- 3. CREATE HELPER FUNCTIONS FOR RLS
-- ============================================================================

-- Function to check if a user is in a team with a lead's owner
CREATE OR REPLACE FUNCTION user_can_see_lead(lead_owner_id UUID, current_user_id UUID, current_tenant_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Admins can see all leads in their tenant
    IF EXISTS (SELECT 1 FROM users WHERE id = current_user_id AND role = 'admin' AND tenant_id = current_tenant_id) THEN
        RETURN TRUE;
    END IF;

    -- Counselors can see leads they own
    IF lead_owner_id = current_user_id THEN
        RETURN TRUE;
    END IF;

    -- Counselors can see leads assigned to any team they belong to
    -- (Check if current user and lead owner share a team)
    IF EXISTS (
        SELECT 1 FROM user_teams ut1
        INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
        WHERE ut1.user_id = current_user_id
        AND ut2.user_id = lead_owner_id
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. RLS SELECT POLICY FOR LEADS
-- ============================================================================
-- Allows users to see leads based on their role and assignments

CREATE POLICY leads_select_policy ON leads
    FOR SELECT
    USING (
        -- Only show leads from the user's tenant
        tenant_id = (current_setting('app.tenant_id')::UUID)
        AND
        -- Apply role-based access control
        (
            -- Admins see all leads in their tenant
            (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) = 'admin'
            OR
            -- Counselors see leads they own
            owner_id = (current_setting('app.user_id')::UUID)
            OR
            -- Counselors see leads assigned to teams they belong to
            EXISTS (
                SELECT 1 FROM user_teams ut1
                INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
                WHERE ut1.user_id = (current_setting('app.user_id')::UUID)
                AND ut2.user_id = leads.owner_id
            )
        )
    );

-- ============================================================================
-- 5. RLS INSERT POLICY FOR LEADS
-- ============================================================================
-- Allows admins and counselors to insert new leads under their tenant

CREATE POLICY leads_insert_policy ON leads
    FOR INSERT
    WITH CHECK (
        -- Lead's tenant must match user's tenant
        tenant_id = (current_setting('app.tenant_id')::UUID)
        AND
        -- Only admins and counselors can insert
        (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) IN ('admin', 'counselor')
    );

-- ============================================================================
-- 6. RLS UPDATE POLICY FOR LEADS (OPTIONAL)
-- ============================================================================
-- Allows users to update leads they own or have access to

CREATE POLICY leads_update_policy ON leads
    FOR UPDATE
    USING (
        -- Only from user's tenant
        tenant_id = (current_setting('app.tenant_id')::UUID)
        AND
        -- Same access rules as SELECT
        (
            (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) = 'admin'
            OR
            owner_id = (current_setting('app.user_id')::UUID)
            OR
            EXISTS (
                SELECT 1 FROM user_teams ut1
                INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
                WHERE ut1.user_id = (current_setting('app.user_id')::UUID)
                AND ut2.user_id = leads.owner_id
            )
        )
    );

-- ============================================================================
-- 7. RLS DELETE POLICY FOR LEADS (OPTIONAL)
-- ============================================================================
-- Only admins can delete leads

CREATE POLICY leads_delete_policy ON leads
    FOR DELETE
    USING (
        tenant_id = (current_setting('app.tenant_id')::UUID)
        AND
        (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) = 'admin'
    );

-- ============================================================================
-- 8. RLS POLICIES FOR APPLICATIONS TABLE
-- ============================================================================
-- Applications inherit access from leads (users can access apps if they can access the lead)

CREATE POLICY applications_select_policy ON applications
    FOR SELECT
    USING (
        -- User can see application if they can see the associated lead
        EXISTS (
            SELECT 1 FROM leads
            WHERE leads.id = applications.lead_id
            AND leads.tenant_id = (current_setting('app.tenant_id')::UUID)
            AND (
                (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) = 'admin'
                OR
                leads.owner_id = (current_setting('app.user_id')::UUID)
                OR
                EXISTS (
                    SELECT 1 FROM user_teams ut1
                    INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
                    WHERE ut1.user_id = (current_setting('app.user_id')::UUID)
                    AND ut2.user_id = leads.owner_id
                )
            )
        )
    );

CREATE POLICY applications_insert_policy ON applications
    FOR INSERT
    WITH CHECK (
        -- User can insert application if they can access the lead
        EXISTS (
            SELECT 1 FROM leads
            WHERE leads.id = applications.lead_id
            AND leads.tenant_id = (current_setting('app.tenant_id')::UUID)
            AND (
                (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) = 'admin'
                OR
                leads.owner_id = (current_setting('app.user_id')::UUID)
                OR
                EXISTS (
                    SELECT 1 FROM user_teams ut1
                    INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
                    WHERE ut1.user_id = (current_setting('app.user_id')::UUID)
                    AND ut2.user_id = leads.owner_id
                )
            )
        )
    );

-- ============================================================================
-- 9. RLS POLICIES FOR TASKS TABLE
-- ============================================================================
-- Tasks inherit access from applications -> leads

CREATE POLICY tasks_select_policy ON tasks
    FOR SELECT
    USING (
        -- User can see task if they can see the associated application/lead
        EXISTS (
            SELECT 1 FROM applications
            INNER JOIN leads ON applications.lead_id = leads.id
            WHERE applications.id = tasks.application_id
            AND leads.tenant_id = (current_setting('app.tenant_id')::UUID)
            AND (
                (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) = 'admin'
                OR
                leads.owner_id = (current_setting('app.user_id')::UUID)
                OR
                EXISTS (
                    SELECT 1 FROM user_teams ut1
                    INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
                    WHERE ut1.user_id = (current_setting('app.user_id')::UUID)
                    AND ut2.user_id = leads.owner_id
                )
            )
        )
    );

CREATE POLICY tasks_insert_policy ON tasks
    FOR INSERT
    WITH CHECK (
        -- User can insert task if they can access the application/lead
        EXISTS (
            SELECT 1 FROM applications
            INNER JOIN leads ON applications.lead_id = leads.id
            WHERE applications.id = tasks.application_id
            AND leads.tenant_id = (current_setting('app.tenant_id')::UUID)
            AND (
                (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) IN ('admin', 'counselor')
                OR
                leads.owner_id = (current_setting('app.user_id')::UUID)
                OR
                EXISTS (
                    SELECT 1 FROM user_teams ut1
                    INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
                    WHERE ut1.user_id = (current_setting('app.user_id')::UUID)
                    AND ut2.user_id = leads.owner_id
                )
            )
        )
    );

CREATE POLICY tasks_update_policy ON tasks
    FOR UPDATE
    USING (
        -- Same access as select
        EXISTS (
            SELECT 1 FROM applications
            INNER JOIN leads ON applications.lead_id = leads.id
            WHERE applications.id = tasks.application_id
            AND leads.tenant_id = (current_setting('app.tenant_id')::UUID)
            AND (
                (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) = 'admin'
                OR
                leads.owner_id = (current_setting('app.user_id')::UUID)
                OR
                EXISTS (
                    SELECT 1 FROM user_teams ut1
                    INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
                    WHERE ut1.user_id = (current_setting('app.user_id')::UUID)
                    AND ut2.user_id = leads.owner_id
                )
            )
        )
    );

CREATE POLICY tasks_delete_policy ON tasks
    FOR DELETE
    USING (
        -- Only admins can delete tasks
        EXISTS (
            SELECT 1 FROM applications
            INNER JOIN leads ON applications.lead_id = leads.id
            WHERE applications.id = tasks.application_id
            AND leads.tenant_id = (current_setting('app.tenant_id')::UUID)
            AND (SELECT role FROM users WHERE id = (current_setting('app.user_id')::UUID) AND tenant_id = (current_setting('app.tenant_id')::UUID)) = 'admin'
        )
    );

-- ============================================================================
-- 10. APPLY AUTO-UPDATE TRIGGERS TO NEW TABLES
-- ============================================================================

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
/*
HOW TO USE RLS WITH JWT:

1. In your backend (Node.js/Express), after verifying the JWT token:
   - Extract: user_id, role, tenant_id
   - Set PostgreSQL session variables:
     
     await pool.query(
       `SET app.user_id = $1; SET app.tenant_id = $2;`,
       [user_id, tenant_id]
     );

2. Then execute any query - RLS will automatically filter results

3. Example middleware in Express:
   
   const authMiddleware = async (req, res, next) => {
     const token = req.headers.authorization?.split(' ')[1];
     const decoded = verifyJWT(token);
     
     if (!decoded) return res.status(401).send('Unauthorized');
     
     // Set RLS context
     await pool.query(
       `SET app.user_id = $1; SET app.tenant_id = $2;`,
       [decoded.user_id, decoded.tenant_id]
     );
     
     req.user = decoded;
     next();
   };

ROLE-BASED ACCESS:

ADMIN:
  - Can see ALL leads in their tenant
  - Can insert leads in their tenant
  - Can update/delete any lead in their tenant

COUNSELOR:
  - Can see leads they own (owner_id = user_id)
  - Can see leads assigned to teams they belong to
  - Can insert leads in their tenant
  - Can update leads they own or have team access to

VIEWER:
  - Can only see leads they own
  - Cannot insert, update, or delete

TEAMS:
  - Support collaboration
  - Multiple counselors can belong to the same team
  - Leads can be assigned to team members

*/
