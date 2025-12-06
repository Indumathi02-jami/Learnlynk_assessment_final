CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. LEADS TABLE
-- ============================================================================
CREATE TABLE leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    owner_id UUID,
    stage TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for leads
CREATE INDEX idx_leads_tenant_id ON leads(tenant_id);
CREATE INDEX idx_leads_tenant_owner ON leads(tenant_id, owner_id);
CREATE INDEX idx_leads_tenant_stage ON leads(tenant_id, stage);
CREATE INDEX idx_leads_email ON leads(email);

-- ============================================================================
-- 2. APPLICATIONS TABLE
-- ============================================================================
CREATE TABLE applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for applications
CREATE INDEX idx_applications_tenant_id ON applications(tenant_id);
CREATE INDEX idx_applications_tenant_lead ON applications(tenant_id, lead_id);

-- ============================================================================
-- 3. TASKS TABLE
-- ============================================================================
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    application_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('call', 'email', 'review')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    due_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraint: due_at must be >= created_at
    CONSTRAINT due_at_after_created CHECK (due_at >= created_at)
);

-- Indexes for tasks
CREATE INDEX idx_tasks_tenant_id ON tasks(tenant_id);
CREATE INDEX idx_tasks_tenant_due_at ON tasks(tenant_id, due_at);
CREATE INDEX idx_tasks_tenant_status ON tasks(tenant_id, status);
CREATE INDEX idx_tasks_application_id ON tasks(application_id);

-- ============================================================================
-- UTILITY FUNCTION: Auto-update updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for auto-update
CREATE TRIGGER update_leads_updated_at BEFORE UPDATE ON leads
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
