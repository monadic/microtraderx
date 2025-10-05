#!/bin/bash
# Stage 1: Hello TraderX - The simplest possible setup
set -e

echo "📦 Stage 1: Hello TraderX"
echo "================================"
echo ""

# Setup
echo "1. Creating ConfigHub structure..."
./setup-structure 1

echo ""
echo "2. Deploying to Kubernetes..."
./deploy 1

echo ""
echo "✅ Stage 1 Complete!"
echo ""
echo "What you created:"
echo "  traderx/"
echo "  └── reference-data (market data service)"
echo ""
echo "Key concepts:"
echo "  - Spaces contain units"
echo "  - Worker deploys them to Kubernetes"
echo ""
echo "Next: ./stages/stage2-three-envs.sh"
