import express from "express";
import cors from "cors";
import routes from "./routes.js";
import authRoutes from "./auth-routes.js";
import { authMiddleware } from "./auth.js";
import pool from "./db.js";

const app = express();
app.use(cors());
app.use(express.json());

// Health check endpoint (no auth required)
app.get("/health", (req, res) => {
  res.json({ status: "ok", message: "Backend is running" });
});

// Auth endpoints (no auth required)
app.use("/auth", authRoutes);

// GET all applications (for dropdown in create task form)
app.get("/applications", authMiddleware, async (req, res) => {
  try {
    console.log('Fetching applications for user:', req.user?.user_id);
    const client = req.dbClient || pool;
    
    const result = await client.query(
      `SELECT id, lead_id, status 
       FROM applications 
       ORDER BY created_at DESC 
       LIMIT 50`
    );
    console.log('Applications returned:', result.rows.length);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching applications:', err);
    res.status(500).json({ error: "Server error" });
  }
});

// Apply authentication middleware to all protected routes
app.use("/tasks", authMiddleware, routes);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`);
});
