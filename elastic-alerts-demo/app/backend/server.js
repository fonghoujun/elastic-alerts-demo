const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.get("/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "ok", db: "connected", timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ status: "error", db: "unreachable", error: err.message });
  }
});

app.get("/api/tasks", async (req, res) => {
  try {
    const { rows } = await pool.query("SELECT * FROM tasks ORDER BY created_at DESC");
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/api/tasks", async (req, res) => {
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: "title is required" });
  try {
    const { rows } = await pool.query(
      "INSERT INTO tasks (title) VALUES ($1) RETURNING *",
      [title]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete("/api/tasks/:id", async (req, res) => {
  try {
    await pool.query("DELETE FROM tasks WHERE id = $1", [req.params.id]);
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => console.log(`Backend listening on :${PORT}`));
