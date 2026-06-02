#!/usr/bin/env bash
# simulate-outage.sh — Stop a container to trigger a Heartbeat "port down" alert
# Usage: bash scripts/simulate-outage.sh [backend|db|frontend] [seconds]

SERVICE="${1:-backend}"
DOWNTIME="${2:-90}"

case "$SERVICE" in
  backend)  CONTAINER="demo-backend"  ;;
  db)       CONTAINER="demo-db"       ;;
  frontend) CONTAINER="demo-frontend" ;;
  *)
    echo "Unknown service: $SERVICE"
    echo "Usage: $0 [backend|db|frontend] [seconds]"
    exit 1 ;;
esac

echo ""
echo "Stopping ${CONTAINER} for ${DOWNTIME}s to simulate outage..."
docker stop "${CONTAINER}"
echo ""
echo "Heartbeat will detect the port as DOWN within ~10 seconds."
echo "Watch Kibana -> Stack Management -> Rules for the alert to fire."
echo ""
echo "Sleeping for ${DOWNTIME}s..."
sleep "${DOWNTIME}"

echo ""
echo "Restarting ${CONTAINER}..."
docker start "${CONTAINER}"
echo "${CONTAINER} is back up. Heartbeat will mark it UP within ~10 seconds."
