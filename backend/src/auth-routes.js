import express from 'express';
import pool from './db.js';
import { generateTestToken } from './auth.js';

const router = express.Router();

// ============================================================================
// POST /auth/login - Generate JWT token for testing
// ============================================================================
// In production, this would verify email/password against users table
// For testing, we accept user_id, role, and tenant_id as parameters

router.post('/login', async (req, res) => {
  try {
    const { user_id, role, tenant_id } = req.body;

    // Validate input
    if (!user_id || !role || !tenant_id) {
      return res.status(400).json({ 
        error: 'Missing required fields: user_id, role, tenant_id' 
      });
    }

    // Verify user exists in database
    const userResult = await pool.query(
      `SELECT id, email, name, role FROM users 
       WHERE id = $1 AND tenant_id = $2`,
      [user_id, tenant_id]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = userResult.rows[0];

    // Verify role matches
    if (user.role !== role) {
      return res.status(400).json({ error: 'Role mismatch' });
    }

    // Generate JWT token
    const token = generateTestToken(user_id, role, tenant_id);

    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
      },
      message: 'Login successful. Use this token in Authorization header: Bearer <token>'
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================================
// GET /auth/users - List all users (for testing)
// ============================================================================
router.get('/users', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, email, name, role, tenant_id FROM users ORDER BY role, email`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching users:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================================
// GET /auth/teams - List all teams (for testing)
// ============================================================================
router.get('/teams', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, tenant_id FROM teams ORDER BY name`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching teams:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================================
// GET /auth/test-tokens - Generate test tokens for all users
// ============================================================================
router.get('/test-tokens', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, email, name, role, tenant_id FROM users ORDER BY role, email`
    );

    const tokens = result.rows.map(user => ({
      user_id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      token: generateTestToken(user.id, user.role, user.tenant_id),
      usage: `curl -H "Authorization: Bearer <token>" http://localhost:5000/tasks/today`
    }));

    res.json({
      message: 'Test tokens generated. Use them in Authorization header.',
      tokens
    });
  } catch (err) {
    console.error('Error generating test tokens:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

export default router;
