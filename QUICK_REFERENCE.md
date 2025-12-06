# Quick Start Reference

## 🎯 System URLs

| Service | URL | Port |
|---------|-----|------|
| Frontend | http://localhost:3001 | 3001 |
| Backend | http://localhost:5000 | 5000 |
| Database | localhost | 5432 |

---

## 🔑 Test User Credentials

Use these user IDs to generate JWT tokens:

### Admin
```
User ID: 660e8400-e29b-41d4-a716-446655440099
Email: admin@example.com
Role: admin
```

### Counselor 1 (Sales Team)
```
User ID: 660e8400-e29b-41d4-a716-446655440001
Email: counselor1@example.com
Role: counselor
```

### Counselor 2 (Sales & Support Teams)
```
User ID: 660e8400-e29b-41d4-a716-446655440002
Email: counselor2@example.com
Role: counselor
```

### Counselor 3 (Support Team)
```
User ID: 660e8400-e29b-41d4-a716-446655440003
Email: counselor3@example.com
Role: counselor
```

### Viewer
```
User ID: 660e8400-e29b-41d4-a716-446655440004
Email: viewer@example.com
Role: viewer
```

**Tenant ID (all users):**
```
550e8400-e29b-41d4-a716-446655440000
```

---

## 🚀 Common Commands

### Get JWT Token
```bash
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "660e8400-e29b-41d4-a716-446655440099",
    "role": "admin",
    "tenant_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

### Get All Test Tokens
```bash
curl http://localhost:5000/auth/test-tokens
```

### Fetch Today's Tasks (with RLS)
```bash
curl -H "Authorization: Bearer <your-token>" \
  http://localhost:5000/tasks/today
```

### Create New Task
```bash
curl -X POST http://localhost:5000/tasks \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
    "application_id": "9e0ebaca6fe4474-9628-31e145997cb8",
    "type": "call",
    "due_at": "2025-12-06T10:00:00Z"
  }'
```

### Mark Task Complete
```bash
curl -X POST http://localhost:5000/tasks/<task-id>/complete \
  -H "Authorization: Bearer <your-token>"
```

---

## 🔐 RLS Access Rules

### Admin Sees:
✅ All leads in tenant
✅ All tasks in tenant

### Counselor Sees:
✅ Leads they own
✅ Leads from team members
✅ Tasks for visible leads

### Viewer Sees:
✅ Own leads only
✅ Own tasks only

### No Auth:
❌ Access Denied (401)

---

## 📊 RLS Test Scenarios

### Scenario 1: Admin Access
```bash
# Admin token
TOKEN=$(curl -s -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user_id":"660e8400-e29b-41d4-a716-446655440099","role":"admin","tenant_id":"550e8400-e29b-41d4-a716-446655440000"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# Admin sees all
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/tasks/today
```

### Scenario 2: Counselor 1 (Sales Team)
```bash
# Sees own leads + Counselor 2 (team member)
# Does NOT see Counselor 3 (different team)
```

### Scenario 3: Counselor 2 (Both Teams)
```bash
# Sees most leads
# Can access both Sales and Support team leads
```

### Scenario 4: Viewer (Read-Only)
```bash
# Can view but cannot create/update
# API returns 403 on POST/PUT
```

---

## 🐛 Quick Troubleshoot

**Backend not responding:**
```bash
curl http://localhost:5000/health
```

**Check backend logs:**
```bash
# Terminal shows real-time logs
# Check for errors like "Cannot find package"
```

**Verify database:**
```bash
psql -U postgres -d learnlynk -c "SELECT COUNT(*) FROM tasks;"
```

**Verify RLS:**
```bash
psql -U postgres -d learnlynk -c "SELECT tablename, rowsecurity FROM pg_tables WHERE tablename='leads';"
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `backend/src/auth.js` | JWT middleware & token generation |
| `backend/src/routes.js` | Task endpoints |
| `backend/src/auth-routes.js` | Login & token endpoints |
| `backend/sql/rls_policies.sql` | RLS setup & policies |
| `backend/sql/rls_seed_data.sql` | Users & teams data |
| `frontend/src/App.js` | React task display |
| `.env` files | Configuration variables |

---

## ✅ Tasks Completed

- [x] Task 1: Database Schema (with RLS support)
- [x] Task 2: Row-Level Security Policies
- [x] Task 3: API Endpoints for task management
- [x] Task 4: Frontend task display & management

All features operational and tested!
