#!/bin/bash
# Stage 3: Three Regions - Custom scale per region
set -e

echo "🌏 Stage 3: Three Regions, Different Trading Volumes"
echo "====================================================="
echo ""

# Setup
echo "1. Creating regional structure with custom scale..."
./setup-structure 3

echo ""
echo "2. Deploying all regions..."
./deploy 3

echo ""
echo "✅ Stage 3 Complete!"
echo ""
echo "What you created:"
echo "  traderx-prod-us/    (3 replicas - NYSE hours)"
echo "  traderx-prod-eu/    (5 replicas - Peak trading)"
echo "  traderx-prod-asia/  (2 replicas - Overnight)"
echo ""
echo "Key concepts:"
echo "  - Same config, different scale"
echo "  - Regional customization"
echo "  - Real business logic!"
echo ""
echo "Verify scale:"
echo "  kubectl get deploy trade-service -n traderx-prod-eu -o jsonpath='{.spec.replicas}'"
echo ""
echo "Next: ./stages/stage4-push-upgrade.sh"
