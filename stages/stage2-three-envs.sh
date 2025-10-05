#!/bin/bash
# Stage 2: Three Environments - Copy configs across spaces
set -e

echo "🌍 Stage 2: Three Environments"
echo "================================"
echo ""

# Setup
echo "1. Creating 3 environments..."
./setup-structure 2

echo ""
echo "2. Deploying only production..."
./deploy 2

echo ""
echo "✅ Stage 2 Complete!"
echo ""
echo "What you created:"
echo "  traderx-dev/        (config only)"
echo "  traderx-staging/    (config only)"
echo "  traderx-prod/       (deployed ✓)"
echo ""
echo "Key concepts:"
echo "  - Spaces = environments"
echo "  - Copy promotes configs"
echo "  - Deploy when ready"
echo ""
echo "Next: ./stages/stage3-three-regions.sh"
