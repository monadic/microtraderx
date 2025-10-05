#!/bin/bash
# Minimal reproduction of worker 404 bug
set -e

echo "=== ConfigHub Worker 404 Bug Reproduction ==="
echo ""

# Use unique space name to avoid conflicts
SPACE_NAME="worker-bug-test-$(date +%s)"

echo "1. Creating test space: $SPACE_NAME"
cub space create $SPACE_NAME

echo ""
echo "2. Creating worker in ConfigHub"
WORKER_OUTPUT=$(cub worker create test-worker --space $SPACE_NAME --json)
echo "$WORKER_OUTPUT" | jq .

WORKER_ID=$(echo "$WORKER_OUTPUT" | jq -r '.id')
echo ""
echo "Worker ID: $WORKER_ID"

echo ""
echo "3. Verifying worker exists in ConfigHub"
cub worker get test-worker --space $SPACE_NAME

echo ""
echo "4. Exporting worker manifest"
cub worker install test-worker --space $SPACE_NAME --export > /tmp/worker-manifest.yaml
echo "Manifest exported to /tmp/worker-manifest.yaml"

echo ""
echo "5. Checking worker ID in manifest"
grep -A 2 "CONFIGHUB_WORKER_ID" /tmp/worker-manifest.yaml

echo ""
echo "6. Deploying worker to Kubernetes"
kubectl apply -f /tmp/worker-manifest.yaml

echo ""
echo "7. Waiting 10 seconds for worker to start..."
sleep 10

echo ""
echo "8. Checking worker pod status"
kubectl get pods -n confighub -l app=test-worker

echo ""
echo "9. Checking worker logs for 404 error"
kubectl logs -n confighub -l app=test-worker --tail=30

echo ""
echo "10. Attempting to fetch worker from ConfigHub API using worker ID"
echo "Worker ID: $WORKER_ID"
cub worker get --space $SPACE_NAME test-worker --json | jq '{id, name, space, condition}'

echo ""
echo "=== Bug Analysis ==="
echo "The worker pod fails with: 'Failed to get bridge worker slug: server returned status 404'"
echo "But the worker clearly exists in ConfigHub (see step 10 output above)"
echo ""
echo "Hypothesis: Worker pod can't find itself via API despite having correct ID"
echo ""
echo "Cleanup:"
echo "  kubectl delete deployment -n confighub test-worker"
echo "  cub worker delete --space $SPACE_NAME test-worker"
echo "  cub space delete $SPACE_NAME"
