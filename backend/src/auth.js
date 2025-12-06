import jwt from 'jsonwebtoken';
import pool from './db.js';

// Middleware to set RLS context based on JWT token
export const authMiddleware = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'No authorization token provided' });
    }

    // Verify JWT token
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');

    const { user_id, role, tenant_id } = decoded;

    if (!user_id || !role || !tenant_id) {
      return res.status(401).json({ error: 'Invalid token structure' });
    }

    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(user_id) || !uuidRegex.test(tenant_id)) {
      return res.status(401).json({ error: 'Invalid UUID format in token' });
    }

    // Get a dedicated client from the pool for this request
    const client = await pool.connect();
    
    try {
      // Set RLS context on this dedicated client connection
      await client.query(`SET app.user_id = '${user_id}'`);
      await client.query(`SET app.tenant_id = '${tenant_id}'`);
      console.log(`RLS Context Set - User: ${user_id}, Tenant: ${tenant_id}, Role: ${role}`);
      
      // Store client in request so routes can use it
      req.dbClient = client;
    } catch (e) {
      client.release();
      console.error('Error setting PostgreSQL variables:', e.message);
      return res.status(500).json({ error: 'Database configuration error' });
    }

    // Attach user info to request for later use
    req.user = { user_id, role, tenant_id };

    // Make sure to release client after response
    res.on('finish', () => {
      if (req.dbClient) {
        req.dbClient.release();
      }
    });

    next();
  } catch (err) {
    console.error('Auth middleware error:', err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

// Helper function to generate a test JWT token
export const generateTestToken = (user_id, role, tenant_id) => {
  const secret = process.env.JWT_SECRET || 'your-secret-key';
  return jwt.sign({ user_id, role, tenant_id }, secret, { expiresIn: '24h' });
};

// Optional: Middleware to check specific roles
export const requireRole = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
};
