#!/bin/bash
# Debug ConfigHub worker API endpoints
set -e

echo "=== Testing ConfigHub Worker API Endpoints ==="
echo ""

# Use unique space name
SPACE_NAME="worker-api-test-$(date +%s)"

echo "1. Creating test space and worker"
SPACE_ID=$(cub space create $SPACE_NAME --json | jq -r '.SpaceID')
echo "Space ID: $SPACE_ID"

WORKER_JSON=$(cub worker create api-test-worker --space $SPACE_NAME --json)
WORKER_ID=$(echo "$WORKER_JSON" | jq -r '.BridgeWorkerID')
echo "Worker ID: $WORKER_ID"
echo ""

echo "2. Get ConfigHub API URL and token"
CUB_API_URL="${CUB_API_URL:-https://hub.confighub.com}"
CUB_TOKEN=$(cub auth get-token)
echo "API URL: $CUB_API_URL"
echo "Token: ${CUB_TOKEN:0:30}..."
echo ""

echo "3. Test GET /bridge_workers/{id} (what worker pod tries)"
echo "curl -H 'Authorization: Bearer \$TOKEN' ${CUB_API_URL}/api/v1/bridge_workers/${WORKER_ID}"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Authorization: Bearer $CUB_TOKEN" \
  "${CUB_API_URL}/api/v1/bridge_workers/${WORKER_ID}")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "Status: $HTTP_STATUS"
echo "Body: $BODY" | jq . 2>/dev/null || echo "$BODY"
echo ""

echo "4. Test GET /spaces/{space_id}/bridge_workers/{worker_slug}"
echo "curl -H 'Authorization: Bearer \$TOKEN' ${CUB_API_URL}/api/v1/spaces/${SPACE_ID}/bridge_workers/api-test-worker"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Authorization: Bearer $CUB_TOKEN" \
  "${CUB_API_URL}/api/v1/spaces/${SPACE_ID}/bridge_workers/api-test-worker")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "Status: $HTTP_STATUS"
echo "Body: $BODY" | jq . 2>/dev/null || echo "$BODY"
echo ""

echo "5. List all workers in space"
echo "curl -H 'Authorization: Bearer \$TOKEN' ${CUB_API_URL}/api/v1/spaces/${SPACE_ID}/bridge_workers"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Authorization: Bearer $CUB_TOKEN" \
  "${CUB_API_URL}/api/v1/spaces/${SPACE_ID}/bridge_workers")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "Status: $HTTP_STATUS"
echo "Body: $BODY" | jq . 2>/dev/null || echo "$BODY"
echo ""

echo "=== Analysis ==="
echo "If endpoint #3 returns 404, that's the bug!"
echo "The worker pod uses GET /bridge_workers/{id} to find itself"
echo "But the API might only support space-scoped lookups"
echo ""
echo "Cleanup:"
echo "  cub worker delete --space $SPACE_NAME api-test-worker"
echo "  cub space delete $SPACE_NAME"
