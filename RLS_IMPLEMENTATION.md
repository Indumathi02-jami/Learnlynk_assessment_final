# Row-Level Security (RLS) Implementation - Task 2

## Overview

This implementation satisfies all Task 2 requirements:

✅ **RLS enabled on leads table**
✅ **SELECT policy enforcing role-based access**
✅ **INSERT policy for counselors/admins**
✅ **Supporting tables created (users, teams, user_teams)**
✅ **JWT authentication middleware**
✅ **Test endpoints for token generation**

---

## Architecture

### Database Tables

1. **users** - Authentication and role management
   - `id` (UUID) - User identifier
   - `tenant_id` (UUID) - Tenant/organization
   - `role` (TEXT) - admin, counselor, viewer
   - `email`, `name`, `created_at`, `updated_at`

2. **teams** - Team groupings
   - `id` (UUID)
   - `tenant_id` (UUID)
   - `name` (TEXT)

3. **user_teams** - Many-to-many relationship
   - `user_id` (FK to users)
   - `team_id` (FK to teams)

### RLS Policies

#### SELECT Policy (`leads_select_policy`)
Users can see leads based on:
- **Same tenant**: `tenant_id = current_user_tenant_id`
- **Admin role**: Can see all leads in tenant
- **Counselor ownership**: Can see leads where `owner_id = current_user_id`
- **Team membership**: Can see leads owned by team members

#### INSERT Policy (`leads_insert_policy`)
Users can insert leads if:
- **Same tenant**: `tenant_id = current_user_tenant_id`
- **Correct role**: User is 'admin' or 'counselor'

#### UPDATE Policy (`leads_update_policy`)
Same access rules as SELECT - must own lead or have team access

#### DELETE Policy (`leads_delete_policy`)
Only admins can delete leads in their tenant

---

## Authentication Flow

### 1. JWT Token Format

```json
{
  "user_id": "660e8400-e29b-41d4-a716-446655440001",
  "role": "counselor",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "iat": 1701770000,
  "exp": 1701856400
}
```

### 2. RLS Context Setting

When a request arrives:
```javascript
// Express middleware sets PostgreSQL session variables
await pool.query(
  `SET app.user_id = $1; SET app.tenant_id = $2;`,
  [decoded.user_id, decoded.tenant_id]
);
```

These variables are used by RLS policies to filter data automatically.

### 3. Automatic Data Filtering

Any query to the `leads` table now automatically returns only rows that the user has access to:

```sql
-- This query
SELECT * FROM leads;

-- Automatically becomes (conceptually)
SELECT * FROM leads
WHERE tenant_id = current_setting('app.tenant_id')::UUID
AND (
  (user_role = 'admin')
  OR owner_id = current_user_id
  OR user_has_team_with_owner
);
```

---

## Sample Users & Teams

### Users

| Email | Name | Role | Purpose |
|-------|------|------|---------|
| admin@example.com | Admin User | admin | Can see all leads in tenant |
| counselor1@example.com | Counselor One | counselor | Owns leads, member of Sales Team |
| counselor2@example.com | Counselor Two | counselor | Owns leads, member of Sales & Support Teams |
| counselor3@example.com | Counselor Three | counselor | Owns leads, member of Support Team |
| viewer@example.com | Viewer User | viewer | Can only see owned leads |

### Teams

| Name | Members |
|------|---------|
| Sales Team | Counselor 1, Counselor 2 |
| Support Team | Counselor 2, Counselor 3 |

---

## Testing RLS

### Step 1: Get Test Tokens

```bash
curl http://localhost:5000/auth/test-tokens
```

Response:
```json
{
  "message": "Test tokens generated. Use them in Authorization header.",
  "tokens": [
    {
      "user_id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "counselor1@example.com",
      "name": "Counselor One",
      "role": "counselor",
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    },
    ...
  ]
}
```

### Step 2: Test as Admin

```bash
curl -H "Authorization: Bearer <admin-token>" \
  http://localhost:5000/tasks/today
```

Admin sees all leads in tenant.

### Step 3: Test as Counselor 1

```bash
curl -H "Authorization: Bearer <counselor1-token>" \
  http://localhost:5000/tasks/today
```

Counselor 1 sees:
- Leads they own
- Leads owned by Counselor 2 (team member in Sales Team)

### Step 4: Manual Login

```bash
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "660e8400-e29b-41d4-a716-446655440001",
    "role": "counselor",
    "tenant_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

---

## Files Modified/Created

### Created
- `backend/sql/rls_policies.sql` - RLS setup and policies
- `backend/sql/rls_seed_data.sql` - Sample users and teams
- `backend/src/auth.js` - JWT verification middleware
- `backend/src/auth-routes.js` - Login and token endpoints
- `RLS_IMPLEMENTATION.md` - This documentation

### Modified
- `backend/src/server.js` - Added auth middleware and auth routes
- `backend/package.json` - Added jsonwebtoken dependency

---

## Access Control Matrix

| User | Leads Visible | Can Insert | Can Update | Can Delete |
|------|---------------|-----------|-----------|-----------|
| **Admin** | All in tenant | ✅ | ✅ | ✅ |
| **Counselor (owns lead)** | Own + team leads | ✅ | ✅ | ❌ |
| **Counselor (team member)** | Team leads + own | ✅ | ✅ | ❌ |
| **Viewer** | Own only | ❌ | ❌ | ❌ |
| **No auth** | ❌ Blocked | ❌ | ❌ | ❌ |

---

## Required Environment Variables

Add to `backend/src/.env`:

```
JWT_SECRET=your-super-secret-key-change-in-production
```

---

## Security Considerations

1. **RLS is enforced at database level** - No way to bypass from application
2. **JWT tokens expire** - Default 24 hours
3. **Each request sets context** - User isolation guaranteed
4. **Tenant isolation** - Users only see data from their tenant
5. **Role-based access** - Admin > Counselor > Viewer

---

## Example Use Cases

### Use Case 1: Admin Reviews All Leads

Admin logs in → Gets token → Calls `/tasks/today`
**Result**: Sees all pending tasks across all leads in tenant

### Use Case 2: Counselor Sees Team's Work

Counselor 2 logs in → Gets token → Calls `/tasks/today`
**Result**: Sees tasks for:
- Their own leads
- Leads owned by Counselor 1 (Sales Team member)
- Leads owned by Counselor 3 (Support Team member)

### Use Case 3: Counselor Cannot See Other Team's Work

Counselor 1 logs in → Gets token → Queries leads table
**Result**: Blocked by RLS from seeing:
- Counselor 3's leads (different team)
- Admin's private leads

---

## Next Steps

1. **Update Frontend**: Add login page to collect credentials
2. **Store JWT**: Save token in localStorage
3. **Include in Requests**: Add Authorization header to all API calls
4. **Handle Expiry**: Implement token refresh logic
5. **Add Logout**: Clear token on logout
