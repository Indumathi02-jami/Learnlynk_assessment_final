import express from "express";
import pool from "./db.js";

const router = express.Router();

// GET tasks due today
router.get("/today", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT id, lead_id, task_type, due_at, is_completed FROM tasks WHERE DATE(due_at) = CURRENT_DATE"
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send("Server error");
  }
});


// Mark task completed
router.post("/:id/complete", async (req, res) => {
  try {
    await pool.query(
      "UPDATE tasks SET is_completed = TRUE WHERE id = $1",
      [req.params.id]
    );
    res.json({ message: "Task completed" });
  } catch (err) {
    console.error(err);
    res.status(500).send("Server error");
  }
});

export default router;
