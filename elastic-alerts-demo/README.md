# Elastic Observability Demo — Port Monitoring & Alerting

A self-contained Docker Compose environment demonstrating:
- A 3-tier application (frontend + backend + PostgreSQL)
- Elastic Heartbeat monitoring every port every 10s
- Kibana alerting when a port goes down

---

## Architecture

```
Frontend (nginx :3000) -> Backend (Express :3001) -> PostgreSQL (:5432)
                                    |
                              Heartbeat monitors all ports
                                    |
                            Elasticsearch (:9200)
                                    |
                              Kibana (:5601)
```

---

## Prerequisites

- Docker Desktop (includes Docker Compose)
- Minimum 6GB RAM allocated to Docker
- Ports 3000, 3001, 5432, 9200, 5601 free

---

## Step 1 — Start everything

```bash
cd elastic-demo
docker compose up --build -d
```

Wait for all containers to show healthy:
```bash
docker compose ps
```

Kibana takes 2-3 minutes to fully initialise after the container starts.
Wait until this command returns "available" before proceeding:

```bash
until curl -s http://localhost:9200/_cluster/health | grep -q 'yellow\|green'; do
  echo "Waiting for Elasticsearch..."; sleep 5
done
echo "Elasticsearch ready"
```

---

## Step 2 — Open the application

| URL                          | What you see          |
| ---------------------------- | --------------------- |
| http://localhost:3000        | Task Manager frontend |
| http://localhost:3001/health | Backend health check  |
| http://localhost:9200        | Elasticsearch         |
| http://localhost:5601        | Kibana                |

> Open Kibana in Chrome or Firefox. Safari can sometimes drop the connection
> during Kibana's slow first boot.

---

## Step 3 — Verify Heartbeat is shipping data

```bash
# Check heartbeat is running without errors
docker logs heartbeat 2>&1 | tail -5

# Check data is in Elasticsearch
curl -s "http://localhost:9200/heartbeat-*/_count" | python3 -m json.tool
```

You should see a count > 0 after about 30 seconds.

To browse the raw data: Kibana -> Discover -> create a data view for `heartbeat-*`

---

## Step 4 — Create a port-down alert in Kibana

1. Open http://localhost:5601
2. Go to **Stack Management -> Rules**
3. Click **Create rule**
4. Choose rule type: **Elasticsearch query**
5. Configure:
   - Name: `Service Port Down`
   - Index: `heartbeat-*`
   - Time field: `@timestamp`
   - Query (paste exactly):
     ```json
     {"query":{"bool":{"must":[{"term":{"monitor.status":"down"}}]}}}
     ```
   - Threshold: count **IS ABOVE** `0`
   - Time window: `2 minutes`
   - Check every: `1 minute`
6. Add action: choose **Server log** (requires no external config)
7. Save the rule

---

## Step 5 — Trigger the alert

```bash
# Stop the backend for 2 minutes to trigger the alert
bash scripts/simulate-outage.sh backend 120

# Or stop the database
bash scripts/simulate-outage.sh db 120

# Or stop the frontend
bash scripts/simulate-outage.sh frontend 120
```

**What happens:**
1. Within ~10s: Heartbeat marks the monitor DOWN (visible in Discover)
2. After ~2 min: Kibana rule fires, alert becomes Active in Stack Management -> Rules
3. After the downtime: container restarts, alert resolves automatically

---

## Useful commands

```bash
# View all container statuses
docker compose ps

# Watch heartbeat logs
docker logs -f heartbeat

# Watch kibana logs
docker logs -f kibana

# Tear down (keeps data volumes)
docker compose down

# Tear down and delete all data
docker compose down -v
```

---

## File structure

```
elastic-demo/
├── docker-compose.yml
├── app/
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   ├── server.js
│   │   └── init.sql
│   └── frontend/
│       ├── Dockerfile
│       ├── nginx.conf
│       └── index.html
├── elastic/
│   ├── kibana/
│   │   └── kibana.yml          <- encryption key for alerting
│   ├── heartbeat/
│   │   └── heartbeat.yml       <- 5 monitor definitions
│   └── metricbeat/
│       └── metricbeat.yml      <- container metrics
└── scripts/
    └── simulate-outage.sh      <- stops a container to trigger alert
```
