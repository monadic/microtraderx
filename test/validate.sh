#!/bin/bash
# Validation script - Check if ConfigHub structure is correct
set -e

echo "🧪 MicroTraderX Validation"
echo "=========================="
echo ""

STAGE=${1:-7}

case $STAGE in
  1)
    echo "Validating Stage 1..."
    cub space get traderx > /dev/null || { echo "❌ Space traderx not found"; exit 1; }
    cub unit get reference-data --space traderx > /dev/null || { echo "❌ Unit reference-data not found"; exit 1; }
    echo "✅ Stage 1 structure valid"
    ;;

  2)
    echo "Validating Stage 2..."
    for env in dev staging prod; do
      cub space get traderx-$env > /dev/null || { echo "❌ Space traderx-$env not found"; exit 1; }
      cub unit get reference-data --space traderx-$env > /dev/null || { echo "❌ Unit in traderx-$env not found"; exit 1; }
    done
    echo "✅ Stage 2 structure valid (3 environments)"
    ;;

  3)
    echo "Validating Stage 3..."
    for region in us eu asia; do
      cub space get traderx-prod-$region > /dev/null || { echo "❌ Space traderx-prod-$region not found"; exit 1; }
      cub unit get trade-service --space traderx-prod-$region > /dev/null || { echo "❌ trade-service in $region not found"; exit 1; }
    done

    # Check replica counts
    us_replicas=$(cub unit get trade-service --space traderx-prod-us --output json | jq -r '.data.spec.replicas // 0')
    eu_replicas=$(cub unit get trade-service --space traderx-prod-eu --output json | jq -r '.data.spec.replicas // 0')
    asia_replicas=$(cub unit get trade-service --space traderx-prod-asia --output json | jq -r '.data.spec.replicas // 0')

    [[ "$us_replicas" == "3" ]] || { echo "❌ US replicas should be 3, got $us_replicas"; exit 1; }
    [[ "$eu_replicas" == "5" ]] || { echo "❌ EU replicas should be 5, got $eu_replicas"; exit 1; }
    [[ "$asia_replicas" == "2" ]] || { echo "❌ Asia replicas should be 2, got $asia_replicas"; exit 1; }

    echo "✅ Stage 3 structure valid (3 regions with correct scale)"
    ;;

  4)
    echo "Validating Stage 4..."
    cub space get traderx-base > /dev/null || { echo "❌ Base space not found"; exit 1; }

    for region in us eu asia; do
      unit_info=$(cub unit get trade-service --space traderx-prod-$region --output json)
      upstream=$(echo "$unit_info" | jq -r '.upstream_unit_id // ""')
      [[ -n "$upstream" ]] || { echo "❌ $region has no upstream link"; exit 1; }
    done

    echo "✅ Stage 4 structure valid (inheritance setup)"
    ;;

  7)
    echo "Validating Stage 7 (complete system)..."

    # Check base
    cub space get traderx-base > /dev/null || { echo "❌ Base space not found"; exit 1; }

    # Check dev/staging
    for env in dev staging; do
      cub space get traderx-$env > /dev/null || { echo "❌ Space traderx-$env not found"; exit 1; }
    done

    # Check regions
    for region in us eu asia; do
      cub space get traderx-prod-$region > /dev/null || { echo "❌ Space traderx-prod-$region not found"; exit 1; }
    done

    echo "✅ Stage 7 structure valid (complete system)"
    ;;

  *)
    echo "Usage: $0 [stage]"
    echo "Stages: 1, 2, 3, 4, 7"
    exit 1
    ;;
esac

echo ""
echo "🎉 Validation successful!"
