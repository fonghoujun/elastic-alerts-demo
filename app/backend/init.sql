CREATE TABLE IF NOT EXISTS tasks (
  id          SERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  done        BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO tasks (title) VALUES
  ('Explore Kibana dashboards'),
  ('Set up Heartbeat monitors'),
  ('Trigger a port alert');
