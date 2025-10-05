#!/bin/bash
# Stage 5: Find and Fix - SQL queries across regions
set -e

echo "🔍 Stage 5: Find and Fix Problems"
echo "=================================="
echo ""

./setup-structure 5
./deploy 5

echo ""
echo "✅ Stage 5 Complete!"
echo ""
echo "🎯 POWER FEATURE: Find and Fix"
echo ""
echo "Example 1: Find high-replica services in EU"
echo "  cub unit list --space 'traderx-prod-eu' \\"
echo "    --where \"Data CONTAINS 'replicas: 5'\""
echo ""
echo "Example 2: Scale down after market close"
echo "  cub run set-replicas --replicas 2 \\"
echo "    --space traderx-prod-eu \\"
echo "    --where \"spec.replicas > 2\""
echo ""
echo "Example 3: Find old versions globally"
echo "  cub unit list --space '*' \\"
echo "    --where \"Data CONTAINS 'trade-service:v1'\""
echo ""
echo "Key concepts:"
echo "  - SQL WHERE clauses"
echo "  - Cross-region queries"
echo "  - Bulk operations"
echo ""
echo "Next: ./stages/stage6-atomic-updates.sh"
