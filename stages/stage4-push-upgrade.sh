#!/bin/bash
# Stage 4: Push-Upgrade - Change base, keep customizations
set -e

echo "🔄 Stage 4: Push-Upgrade Pattern"
echo "================================"
echo ""

# Setup
echo "1. Creating base + regions with inheritance..."
./setup-structure 4

echo ""
echo "2. Deploying..."
./deploy 4

echo ""
echo "✅ Stage 4 Complete!"
echo ""
echo "Structure:"
echo "  traderx-base/           (shared config)"
echo "  ├── prod-us/            (3 replicas)"
echo "  ├── prod-eu/            (5 replicas)"
echo "  └── prod-asia/          (2 replicas)"
echo ""
echo "🎯 THE MAGIC:"
echo "  Update base → all regions get new algorithm"
echo "  Regional replicas → PRESERVED!"
echo ""
echo "Try it yourself:"
echo "  # Update algorithm in base"
echo "  cub unit update trade-service --space traderx-base \\"
echo "    --patch '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"trade-service\",\"env\":[{\"name\":\"TRADING_ALGORITHM\",\"value\":\"v2\"}]}]}}}}'"
echo ""
echo "  # Push to all regions (keeps their replicas!)"
echo "  cub unit update --upgrade --patch --space 'traderx-prod-*'"
echo ""
echo "Next: ./stages/stage5-find-and-fix.sh"
