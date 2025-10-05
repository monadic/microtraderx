#!/bin/bash
# Stage 6: Atomic Updates - Changesets for related services
set -e

echo "⚛️  Stage 6: Atomic Multi-Service Updates"
echo "========================================="
echo ""

./setup-structure 6
./deploy 6

echo ""
echo "✅ Stage 6 Complete!"
echo ""
echo "🎯 POWER FEATURE: Changesets"
echo ""
echo "Problem: New market data format requires updating BOTH services"
echo "Solution: Atomic changeset - both or neither!"
echo ""
echo "Try it yourself:"
echo ""
echo "  # Create changeset"
echo "  cub changeset create market-data-v2"
echo ""
echo "  # Add both updates (new format + compatible version)"
echo "  cub unit update reference-data --space traderx-prod-us \\"
echo "    --patch '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"reference-data\",\"image\":\"traderx/reference-data:v2\"}]}}}}'"
echo ""
echo "  cub unit update trade-service --space traderx-prod-us \\"
echo "    --patch '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"trade-service\",\"image\":\"traderx/trade-service:v2\"}]}}}}'"
echo ""
echo "  # Apply atomically - both deploy together!"
echo "  cub changeset apply market-data-v2"
echo ""
echo "Key concepts:"
echo "  - Atomic operations"
echo "  - No partial failures"
echo "  - Related services stay in sync"
echo ""
echo "Next: ./stages/stage7-emergency-bypass.sh"
