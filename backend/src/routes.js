import express from "express";
import pool from "./db.js";

const router = express.Router();

// GET tasks due today (status = pending)
router.get("/today", async (req, res) => {
  try {
    // Log user context for debugging RLS
    console.log('Fetching tasks for user:', req.user);
    
    // Use the dedicated client with RLS context set
    const client = req.dbClient || pool;
    
    const result = await client.query(
      `SELECT id, application_id, type, due_at, status, tenant_id 
       FROM tasks 
       WHERE DATE(due_at) = CURRENT_DATE 
       AND status != 'completed'
       ORDER BY due_at ASC`
    );
    
    console.log('Tasks returned:', result.rows.length, 'for user:', req.user.user_id);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching tasks:', err);
    res.status(500).send("Server error");
  }
});

// GET all tasks for a tenant
router.get("/tenant/:tenant_id", async (req, res) => {
  try {
    const { tenant_id } = req.params;
    const client = req.dbClient || pool;
    
    const result = await client.query(
      `SELECT id, application_id, type, due_at, status, tenant_id 
       FROM tasks 
       WHERE tenant_id = $1
       ORDER BY due_at DESC`,
      [tenant_id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send("Server error");
  }
});

// POST: Create a new task (FIXED VERSION)
router.post("/", async (req, res) => {
  try {
    let { tenant_id, application_id, type, due_at } = req.body;

    // Disallow viewers from creating tasks (enforce role-based permission)
    if (req.user?.role === 'viewer') {
      return res.status(403).json({ error: 'Insufficient permissions to create tasks' });
    }

    // Validation
    if (!tenant_id || !application_id || !type) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    if (!['call', 'email', 'review'].includes(type)) {
      return res.status(400).json({ error: "Invalid task type" });
    }

    // Convert due_at to a Date object
    let dueDate = new Date(due_at);

    // Auto-fix invalid or past due_at
    if (!due_at || isNaN(dueDate.getTime()) || dueDate <= new Date()) {
      dueDate = new Date(Date.now() + 60 * 60 * 1000); // +1 hour
      console.log("Auto-adjusted due_at →", dueDate);
    }

    const client = req.dbClient || pool;

    const result = await client.query(
      `INSERT INTO tasks (tenant_id, application_id, type, due_at, status)
       VALUES ($1, $2, $3, $4, 'pending')
       RETURNING id, application_id, type, due_at, status, tenant_id`,
      [tenant_id, application_id, type, dueDate]
    );

    // Log created task for debugging (helps verify server-side due_at)
    console.log('Task created:', result.rows[0]);

    res.status(201).json({ success: true, task: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).send("Server error");
  }
});

// POST: Mark task as completed
router.post("/:id/complete", async (req, res) => {
  try {
    const { id } = req.params;
    const client = req.dbClient || pool;
    
    const result = await client.query(
      `UPDATE tasks 
       SET status = 'completed' 
       WHERE id = $1
       RETURNING id, status`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Task not found" });
    }

    res.json({ success: true, message: "Task completed", task: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).send("Server error");
  }
});

// POST: Cancel a task
router.post("/:id/cancel", async (req, res) => {
  try {
    const { id } = req.params;
    const client = req.dbClient || pool;
    
    const result = await client.query(
      `UPDATE tasks 
       SET status = 'cancelled' 
       WHERE id = $1
       RETURNING id, status`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Task not found" });
    }

    res.json({ success: true, message: "Task cancelled", task: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).send("Server error");
  }
});

// GET all applications (for dropdown in create task form)
router.get("/applications", async (req, res) => {
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

export default router;
