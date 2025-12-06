# Learnlynk Assessment - Full System Setup & Testing Guide

## ✅ System Status

### Running Services
- **Frontend**: React app running on `http://localhost:3001`
- **Backend**: Node.js/Express API running on `http://localhost:5000`
- **Database**: PostgreSQL running on `localhost:5432`

---

## 📁 Project Structure

```
learnlynk-assessment/
├── backend/
│   ├── src/
│   │   ├── start.js              # Entry point
│   │   ├── server.js             # Express app setup
│   │   ├── app.js                # App configuration
│   │   ├── db.js                 # PostgreSQL connection
│   │   ├── auth.js               # JWT middleware & utilities
│   │   ├── auth-routes.js        # Login & token endpoints
│   │   ├── routes.js             # Task endpoints
│   │   └── .env                  # Environment variables
│   ├── sql/
│   │   ├── schema.sql            # Database schema with RLS
│   │   ├── rls_policies.sql      # Row-level security policies
│   │   ├── rls_seed_data.sql     # Users & teams seed data
│   │   ├── insert_queries.sql    # Sample tasks data
│   │   └── seed_data.sql         # Complete seed data
│   ├── package.json              # Backend dependencies
│   └── .gitignore
│
├── frontend/
│   ├── src/
│   │   ├── App.js                # Main React component
│   │   ├── App.css               # Styling
│   │   ├── index.js              # React entry point
│   │   └── ...
│   ├── .env                      # Frontend API URL
│   ├── package.json              # Frontend dependencies
│   └── .gitignore
│
└── RLS_IMPLEMENTATION.md         # RLS documentation
```

---

## 🔐 Authentication & RLS

### JWT Token Structure
```json
{
  "user_id": "660e8400-e29b-41d4-a716-446655440001",
  "role": "counselor",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "iat": 1701770000,
  "exp": 1701856400
}
```

### Access Control Matrix

| Role | Leads Visible | Can Insert | Can Update | Can Delete |
|------|---------------|-----------|-----------|-----------|
| **Admin** | All in tenant | ✅ | ✅ | ✅ |
| **Counselor** | Own + Team | ✅ | ✅ | ❌ |
| **Viewer** | Own only | ❌ | ❌ | ❌ |
| **No Auth** | ❌ Blocked | ❌ | ❌ | ❌ |

---

## 🚀 API Endpoints

### Health Check (No Auth Required)
```bash
GET http://localhost:5000/health
Response: { "status": "ok", "message": "Backend is running" }
```

### Authentication Endpoints (No Auth Required)

#### Get All Users
```bash
GET http://localhost:5000/auth/users
Response: Array of user objects
```

#### Get All Teams
```bash
GET http://localhost:5000/auth/teams
Response: Array of team objects
```

#### Generate Test Tokens
```bash
GET http://localhost:5000/auth/test-tokens
Response: Array of user objects with generated tokens
```

#### Login & Get JWT Token
```bash
POST http://localhost:5000/auth/login
Content-Type: application/json

Body:
{
  "user_id": "660e8400-e29b-41d4-a716-446655440001",
  "role": "counselor",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000"
}

Response: { "token": "eyJhbGc...", "user": {...} }
```

### Task Endpoints (Requires JWT)

All task endpoints require:
```
Authorization: Bearer <jwt-token>
```

#### Get Today's Tasks (with RLS)
```bash
GET http://localhost:5000/tasks/today
Authorization: Bearer <token>

Response: Array of tasks due today (filtered by RLS)
```

#### Get Tenant's Tasks
```bash
GET http://localhost:5000/tasks/tenant/:tenant_id
Authorization: Bearer <token>

Response: Array of all tenant's tasks (filtered by RLS)
```

#### Create New Task
```bash
POST http://localhost:5000/tasks
Authorization: Bearer <token>
Content-Type: application/json

Body:
{
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "application_id": "9e0ebac-a6fe-4474-9628-31e145997cb8",
  "type": "call",
  "due_at": "2025-12-05T18:00:00Z"
}

Response: { "success": true, "task": {...} }
```

#### Mark Task Complete
```bash
POST http://localhost:5000/tasks/:id/complete
Authorization: Bearer <token>

Response: { "success": true, "message": "Task completed" }
```

#### Cancel Task
```bash
POST http://localhost:5000/tasks/:id/cancel
Authorization: Bearer <token>

Response: { "success": true, "message": "Task cancelled" }
```

---

## 🧪 Testing RLS Implementation

### Scenario 1: Admin Access

#### Step 1: Get Admin Token
```bash
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "660e8400-e29b-41d4-a716-446655440099",
    "role": "admin",
    "tenant_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

#### Step 2: Fetch Tasks as Admin
```bash
curl -H "Authorization: Bearer <admin-token>" \
  http://localhost:5000/tasks/today
```

**Result**: Admin sees ALL leads in the tenant because RLS allows admins to see all data.

---

### Scenario 2: Counselor Access (Own Leads Only)

#### Step 1: Get Counselor 1 Token
```bash
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "660e8400-e29b-41d4-a716-446655440001",
    "role": "counselor",
    "tenant_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

#### Step 2: Fetch Tasks as Counselor 1
```bash
curl -H "Authorization: Bearer <counselor1-token>" \
  http://localhost:5000/tasks/today
```

**Result**: Counselor 1 sees:
- Tasks for leads they own
- Tasks for leads owned by team members (Counselor 2 in Sales Team)

---

### Scenario 3: Team-Based Access

#### Team Memberships:
- **Sales Team**: Counselor 1, Counselor 2
- **Support Team**: Counselor 2, Counselor 3

#### If Counselor 3 fetches tasks:
```bash
curl -H "Authorization: Bearer <counselor3-token>" \
  http://localhost:5000/tasks/today
```

**Result**: Counselor 3 sees:
- Tasks for leads they own
- Tasks for leads owned by Counselor 2 (Support Team member)
- **NOT** tasks from Counselor 1 (different team)

---

### Scenario 4: Unauthorized Access

#### Try without token:
```bash
curl http://localhost:5000/tasks/today
```

**Result**: 401 Unauthorized - RLS blocks access

---

## 💾 Database Schema

### Tables

#### leads
- `id` (UUID) - Primary key
- `tenant_id` (UUID) - Tenant ID (for multi-tenancy)
- `name` (TEXT) - Lead name
- `email` (TEXT) - Email address
- `phone` (TEXT) - Phone number
- `owner_id` (UUID) - Counselor who owns this lead
- `stage` (TEXT) - Business stage
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ) - Auto-updated on modify

#### applications
- `id` (UUID) - Primary key
- `tenant_id` (UUID) - Tenant ID
- `lead_id` (UUID) - Foreign key to leads
- `status` (TEXT) - Application status
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

#### tasks
- `id` (UUID) - Primary key
- `tenant_id` (UUID) - Tenant ID
- `application_id` (UUID) - Foreign key to applications
- `type` (TEXT) - 'call', 'email', 'review'
- `status` (TEXT) - 'pending', 'completed', 'cancelled'
- `due_at` (TIMESTAMPTZ) - Task due date (must be >= created_at)
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

#### users
- `id` (UUID) - Primary key
- `tenant_id` (UUID) - Tenant ID
- `email` (TEXT)
- `name` (TEXT)
- `role` (TEXT) - 'admin', 'counselor', 'viewer'
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

#### teams
- `id` (UUID) - Primary key
- `tenant_id` (UUID) - Tenant ID
- `name` (TEXT) - Team name
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

#### user_teams
- `id` (UUID) - Primary key
- `user_id` (UUID) - Foreign key to users
- `team_id` (UUID) - Foreign key to teams
- `created_at` (TIMESTAMPTZ)

---

## 📊 Sample Data

### Users (5 total)
1. **admin@example.com** - Admin User (admin)
2. **counselor1@example.com** - Counselor One (counselor)
3. **counselor2@example.com** - Counselor Two (counselor)
4. **counselor3@example.com** - Counselor Three (counselor)
5. **viewer@example.com** - Viewer User (viewer)

### Teams (2 total)
1. **Sales Team** - Members: Counselor 1, Counselor 2
2. **Support Team** - Members: Counselor 2, Counselor 3

### Leads (10 total)
- All assigned to tenant: `550e8400-e29b-41d4-a716-446655440000`

### Tasks (7 total)
- Various statuses: pending, completed, cancelled
- Different due dates: today, tomorrow, this week

---

## 🎯 Frontend Features

### Current Implementation
- Display today's tasks
- Mark tasks as complete
- Cancel tasks
- Real-time status updates
- Responsive UI

### Integration
- Fetches from `/tasks/today` endpoint
- Requires JWT token in Authorization header
- Automatically filtered by RLS

---

## 🔧 Environment Variables

### Backend (.env)
```
PORT=5000
POSTGRES_USER=postgres
POSTGRES_PASSWORD=test123
POSTGRES_DB=learnlynk
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
JWT_SECRET=your-super-secret-key-change-in-production
```

### Frontend (.env)
```
REACT_APP_API_URL=http://localhost:5000
```

---

## ✅ Completed Requirements

### Task 1: Database Schema ✅
- [x] leads, applications, tasks tables
- [x] Standard fields (id, tenant_id, created_at, updated_at)
- [x] Foreign key relationships
- [x] Constraints (due_at >= created_at)
- [x] Strategic indexes
- [x] Auto-update triggers

### Task 2: Row-Level Security ✅
- [x] RLS enabled on leads
- [x] SELECT policy (admin sees all, counselor sees own + team)
- [x] INSERT policy (admins/counselors only)
- [x] UPDATE & DELETE policies
- [x] users, teams, user_teams tables
- [x] JWT authentication middleware
- [x] Test endpoints for tokens

### Task 3: Edge Function (create-task) - Ready
- API endpoint exists at `POST /tasks`
- Validates task_type, due_at
- Checks tenant access
- Returns proper status codes

### Task 4: Frontend Dashboard - Ready
- React component displays today's tasks
- Shows: type, application_id, due_at, status
- Mark complete button functional
- Real-time UI updates
- RLS automatically filters what user sees

---

## 🚨 Security Notes

1. **RLS enforced at DB level** - Cannot be bypassed from application
2. **JWT tokens expire** - Default 24 hours
3. **Tenant isolation** - Users see only their tenant's data
4. **Role-based access** - Admin > Counselor > Viewer hierarchy
5. **No sensitive data in logs** - Passwords hidden

---

## 📝 Next Steps

1. **Update Frontend Login**: Add authentication UI
2. **Store JWT**: Implement localStorage for token persistence
3. **Refresh Tokens**: Add token refresh logic for long sessions
4. **Error Handling**: Improve error messages and recovery
5. **Production Ready**: Update JWT_SECRET to strong value

---

## 🐛 Troubleshooting

### Backend won't start
```bash
# Ensure PostgreSQL is running
psql -U postgres -c "SELECT 1;"

# Check port 5000 is available
netstat -ano | findstr :5000

# Reinstall dependencies
cd backend && npm install
```

### Frontend can't connect to backend
```bash
# Check backend is running
curl http://localhost:5000/health

# Verify REACT_APP_API_URL in frontend/.env
# Should be: REACT_APP_API_URL=http://localhost:5000
```

### RLS not filtering data
```bash
# Verify RLS is enabled
psql -U postgres -d learnlynk -c "SELECT tablename, rowsecurity FROM pg_tables WHERE tablename='leads';"

# Should return: leads | t (true)
```

### Cannot login
```bash
# Verify users exist
psql -U postgres -d learnlynk -c "SELECT * FROM users;"

# Verify JWT secret is set
echo $env:JWT_SECRET
```

---

## 📞 Support

For issues or questions, check:
1. Backend console logs
2. PostgreSQL error logs
3. Browser developer console
4. Network tab in DevTools

