#!/bin/bash
# Cleanup script for MicroTraderX testing
# Removes all ConfigHub spaces and Kubernetes resources

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🧹 MicroTraderX Cleanup${NC}"
echo "======================="
echo ""

PREFIX=$(bin/get-prefix 2>/dev/null || echo "")

if [[ -z "$PREFIX" ]]; then
  echo -e "${RED}Error: No prefix found. Run './setup-structure' first.${NC}"
  exit 1
fi

echo "Using prefix: $PREFIX"
echo ""

# Confirm deletion
echo -e "${YELLOW}⚠️  WARNING: This will delete:${NC}"
echo "  - All ConfigHub spaces starting with '$PREFIX-traderx'"
echo "  - All Kubernetes namespaces starting with '$PREFIX-traderx'"
echo "  - ConfigHub workers"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# Delete Kubernetes resources first
echo "🗑️  Cleaning up Kubernetes namespaces..."
for ns in $(kubectl get namespaces -o name | grep "${PREFIX}-traderx" | sed 's|namespace/||'); do
  echo "  Deleting namespace: $ns"
  kubectl delete namespace "$ns" --wait=false 2>/dev/null || true
done

# Delete confighub namespace if it exists
if kubectl get namespace confighub &>/dev/null; then
  echo "  Deleting confighub namespace"
  kubectl delete namespace confighub --wait=false 2>/dev/null || true
fi

echo ""

# Delete ConfigHub spaces
echo "🗑️  Cleaning up ConfigHub spaces..."

# Get all spaces with our prefix
spaces=$(cub space list 2>/dev/null | grep "^${PREFIX}-traderx" | awk '{print $1}' || echo "")

if [[ -n "$spaces" ]]; then
  for space in $spaces; do
    echo "  Deleting space: $space"

    # Delete workers first
    workers=$(cub worker list --space "$space" 2>/dev/null | grep -v "^NAME" | awk '{print $1}' || echo "")
    for worker in $workers; do
      echo "    Deleting worker: $worker"
      cub worker delete "$worker" --space "$space" 2>/dev/null || true
    done

    # Delete space
    cub space delete "$space" --recursive 2>/dev/null || true
  done
else
  echo "  No spaces found with prefix '$PREFIX-traderx'"
fi

echo ""

# Clean up prefix file
if [[ -f .microtraderx-prefix ]]; then
  echo "🗑️  Removing prefix file..."
  rm -f .microtraderx-prefix
  echo "  Deleted .microtraderx-prefix"
fi

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo "You can now run a fresh tutorial with:"
echo "  ./setup-structure [stage]"
echo "  ./deploy [stage]"
