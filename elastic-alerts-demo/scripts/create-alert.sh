#!/usr/bin/env bash
# create-alert.sh

KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
HEADERS=(-H "kbn-xsrf: true" -H "Content-Type: application/json")

echo ""
echo "Waiting for Kibana to be ready..."
until curl -s "${KIBANA_URL}/api/status" | grep -q '"level":"available"'; do
  printf "."
  sleep 5
done
echo ""
echo "Kibana is ready."

echo ""
echo "Checking for existing connector..."
EXISTING=$(curl -s "${KIBANA_URL}/api/actions/connectors" "${HEADERS[@]}")
CONNECTOR_ID=$(echo "$EXISTING" | python3 -c "
import sys, json
connectors = json.load(sys.stdin)
for c in connectors:
    if c.get('name') == 'Demo Server Log':
        print(c['id'])
        break
" 2>/dev/null)

if [ -n "$CONNECTOR_ID" ]; then
  echo "Found existing connector. ID: ${CONNECTOR_ID}"
else
  echo "Creating server-log connector..."
  CONNECTOR_RAW=$(curl -s -X POST "${KIBANA_URL}/api/actions/connector" \
    "${HEADERS[@]}" \
    -d '{
      "name": "Demo Server Log",
      "connector_type_id": ".server-log",
      "config": {}
    }')
  CONNECTOR_ID=$(echo "$CONNECTOR_RAW" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('id', ''))
" 2>/dev/null)
  if [ -z "$CONNECTOR_ID" ]; then
    echo "Connector creation failed:"
    echo "$CONNECTOR_RAW"
    exit 1
  fi
  echo "Connector created. ID: ${CONNECTOR_ID}"
fi

echo ""
echo "Creating 'Service Port Down' alert rule..."
RULE_RAW=$(curl -s -X POST "${KIBANA_URL}/api/alerting/rule" \
  "${HEADERS[@]}" \
  -d "{
    \"name\": \"Service Port Down\",
    \"rule_type_id\": \".es-query\",
    \"consumer\": \"alerts\",
    \"schedule\": { \"interval\": \"1m\" },
    \"params\": {
      \"index\": [\"heartbeat-*\"],
      \"timeField\": \"@timestamp\",
      \"timeWindowSize\": 2,
      \"timeWindowUnit\": \"m\",
      \"thresholdComparator\": \">\",
      \"threshold\": [0],
      \"size\": 100,
      \"esQuery\": \"{\\\"query\\\":{\\\"term\\\":{\\\"monitor.status\\\":\\\"down\\\"}}}\",
      \"searchType\": \"esQuery\"
    },
    \"actions\": [
      {
        \"id\": \"${CONNECTOR_ID}\",
        \"group\": \"query matched\",
        \"frequency\": {
          \"notify_when\": \"onActiveAlert\",
          \"throttle\": null,
          \"summary\": false
        },
        \"params\": {
          \"level\": \"error\",
          \"message\": \"ALERT: A monitored port is DOWN. Check Kibana -> Stack Management -> Rules.\"
        }
      }
    ]
  }")

RULE_ID=$(echo "$RULE_RAW" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('id', ''))
" 2>/dev/null)

if [ -n "$RULE_ID" ]; then
  echo ""
  echo "Alert rule created successfully!"
  echo "Rule ID: ${RULE_ID}"
  echo ""
  echo "View: ${KIBANA_URL}/app/management/insightsAndAlerting/triggersActions/rules"
  echo ""
  echo "To trigger the alert:"
  echo "  bash scripts/simulate-outage.sh backend 120"
else
  echo ""
  echo "Rule creation failed. Response:"
  echo "$RULE_RAW" | python3 -m json.tool 2>/dev/null || echo "$RULE_RAW"
  echo ""
  echo "Manual fallback — create in Kibana UI:"
  echo "  1. Stack Management -> Rules -> Create rule"
  echo "  2. Type: Elasticsearch query"
  echo "  3. Index: heartbeat-*  |  Time field: @timestamp"
  echo "  4. Query: {"query":{"term":{"monitor.status":"down"}}}"
  echo "  5. Threshold: count IS ABOVE 0 in last 2 minutes"
  echo "  6. Check every: 1 minute"
  echo "  7. Action: Server log -> Save"
fi