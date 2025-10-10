#!/bin/bash
# Comprehensive stage testing for MicroTraderX
# Tests both ConfigHub structure AND Kubernetes deployment

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 MicroTraderX Stage Test Suite${NC}"
echo "================================="
echo ""

STAGE=${1:-1}
PREFIX=$(bin/get-prefix 2>/dev/null || echo "test")

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test helper functions
test_passed() {
  ((TESTS_PASSED++))
  ((TESTS_TOTAL++))
  echo -e "  ${GREEN}✓${NC} $1"
}

test_failed() {
  ((TESTS_FAILED++))
  ((TESTS_TOTAL++))
  echo -e "  ${RED}✗${NC} $1"
  echo -e "    ${RED}Error: $2${NC}"
}

test_section() {
  echo ""
  echo -e "${YELLOW}Testing: $1${NC}"
}

# Check if space exists
check_space() {
  local space=$1
  if cub space get "$space" &>/dev/null; then
    test_passed "Space '$space' exists"
    return 0
  else
    test_failed "Space '$space' exists" "Space not found"
    return 1
  fi
}

# Check if unit exists
check_unit() {
  local unit=$1
  local space=$2
  if cub unit get "$unit" --space "$space" &>/dev/null; then
    test_passed "Unit '$unit' exists in '$space'"
    return 0
  else
    test_failed "Unit '$unit' exists in '$space'" "Unit not found"
    return 1
  fi
}

# Check unit replicas
check_replicas() {
  local unit=$1
  local space=$2
  local expected=$3
  local actual=$(cub unit get "$unit" --space "$space" --output json 2>/dev/null | jq -r '.data.spec.replicas // 0')
  if [[ "$actual" == "$expected" ]]; then
    test_passed "Unit '$unit' has $expected replicas"
    return 0
  else
    test_failed "Unit '$unit' has $expected replicas" "Got $actual replicas"
    return 1
  fi
}

# Check upstream link
check_upstream() {
  local unit=$1
  local space=$2
  local upstream=$(cub unit get "$unit" --space "$space" --output json 2>/dev/null | jq -r '.upstream_unit_id // ""')
  if [[ -n "$upstream" ]]; then
    test_passed "Unit '$unit' has upstream link"
    return 0
  else
    test_failed "Unit '$unit' has upstream link" "No upstream found"
    return 1
  fi
}

# Check Kubernetes deployment
check_k8s_deployment() {
  local deployment=$1
  local namespace=$2
  if kubectl get deployment "$deployment" -n "$namespace" &>/dev/null; then
    test_passed "K8s deployment '$deployment' exists in '$namespace'"
    return 0
  else
    test_failed "K8s deployment '$deployment' exists in '$namespace'" "Deployment not found"
    return 1
  fi
}

# Check pod status
check_pod_running() {
  local label=$1
  local namespace=$2
  local status=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  if [[ "$status" == "Running" ]]; then
    test_passed "Pod with label '$label' is Running"
    return 0
  else
    test_failed "Pod with label '$label' is Running" "Status: $status"
    return 1
  fi
}

# Check Links
check_links() {
  local unit=$1
  local space=$2
  local expected_count=$3
  local actual_count=$(cub link list --space "$space" --from "$unit" 2>/dev/null | grep -c "^" || echo "0")
  if [[ "$actual_count" -ge "$expected_count" ]]; then
    test_passed "Unit '$unit' has at least $expected_count links"
    return 0
  else
    test_failed "Unit '$unit' has at least $expected_count links" "Found $actual_count links"
    return 1
  fi
}

# Check namespace in YAML
check_yaml_namespace() {
  local unit=$1
  local space=$2
  local expected=$3
  local actual=$(cub unit get "$unit" --space "$space" --output json 2>/dev/null | jq -r '.data.metadata.namespace // ""')
  if [[ "$actual" == "$expected" ]]; then
    test_passed "Unit '$unit' namespace is '$expected'"
    return 0
  else
    test_failed "Unit '$unit' namespace is '$expected'" "Got '$actual'"
    return 1
  fi
}

# Stage-specific tests
case $STAGE in
  1)
    echo "Testing Stage 1: Hello TraderX"
    echo "Concept: Spaces, Units, Workers, Deployment"
    echo ""

    test_section "ConfigHub Structure"
    check_space "${PREFIX}-traderx"
    check_unit "reference-data" "${PREFIX}-traderx"

    test_section "Kubernetes Deployment"
    if kubectl get namespace "${PREFIX}-traderx" &>/dev/null; then
      check_k8s_deployment "reference-data" "${PREFIX}-traderx"
      check_pod_running "app=reference-data" "${PREFIX}-traderx"
    else
      echo -e "  ${YELLOW}⚠${NC} Kubernetes namespace not found (deploy not run?)"
    fi
    ;;

  2)
    echo "Testing Stage 2: Three Environments"
    echo "Concept: Environment hierarchy with inheritance"
    echo ""

    test_section "ConfigHub Structure - Base"
    check_space "${PREFIX}-traderx"
    check_unit "reference-data" "${PREFIX}-traderx"

    test_section "ConfigHub Structure - Environments"
    for env in dev staging prod; do
      check_space "${PREFIX}-traderx-$env"
      check_unit "reference-data" "${PREFIX}-traderx-$env"
      check_upstream "reference-data" "${PREFIX}-traderx-$env"
    done

    test_section "Kubernetes Deployment (prod only)"
    if kubectl get namespace "${PREFIX}-traderx-prod" &>/dev/null; then
      check_k8s_deployment "reference-data" "${PREFIX}-traderx-prod"
    else
      echo -e "  ${YELLOW}⚠${NC} Kubernetes not deployed (expected for Stage 2)"
    fi
    ;;

  3)
    echo "Testing Stage 3: Regional Deployment with Links"
    echo "Concept: Regional variants, Links, namespace isolation"
    echo ""

    test_section "ConfigHub Structure - Base"
    check_space "${PREFIX}-traderx-base"
    check_unit "reference-data" "${PREFIX}-traderx-base"
    check_unit "trade-service" "${PREFIX}-traderx-base"

    test_section "ConfigHub Structure - Infrastructure"
    check_space "${PREFIX}-traderx-infra"
    check_unit "ns-base" "${PREFIX}-traderx-infra"
    for region in us eu asia; do
      check_unit "ns-$region" "${PREFIX}-traderx-infra"
    done

    test_section "ConfigHub Structure - Regions"
    for region in us eu asia; do
      check_space "${PREFIX}-traderx-prod-$region"
      check_unit "reference-data" "${PREFIX}-traderx-prod-$region"
      check_unit "trade-service" "${PREFIX}-traderx-prod-$region"
      # Note: Upstream links exist but focus of Stage 3 is Links (tested below)
    done

    test_section "Regional Customizations"
    check_replicas "trade-service" "${PREFIX}-traderx-prod-us" "3"
    check_replicas "trade-service" "${PREFIX}-traderx-prod-eu" "5"
    check_replicas "trade-service" "${PREFIX}-traderx-prod-asia" "2"

    test_section "Links Configuration"
    for region in us eu asia; do
      # Check if unit has links (at least 2: namespace + reference-data)
      check_links "trade-service" "${PREFIX}-traderx-prod-$region" "2"
    done

    test_section "Namespace Placeholders"
    check_yaml_namespace "reference-data" "${PREFIX}-traderx-prod-us" "confighubplaceholder"
    check_yaml_namespace "trade-service" "${PREFIX}-traderx-prod-us" "confighubplaceholder"

    test_section "Kubernetes Deployment"
    for region in us eu asia; do
      if kubectl get namespace "${PREFIX}-traderx-prod-$region" &>/dev/null; then
        check_k8s_deployment "reference-data" "${PREFIX}-traderx-prod-$region"
        check_k8s_deployment "trade-service" "${PREFIX}-traderx-prod-$region"
        check_pod_running "app=reference-data" "${PREFIX}-traderx-prod-$region"
        check_pod_running "app=trade-service" "${PREFIX}-traderx-prod-$region"
      else
        echo -e "  ${YELLOW}⚠${NC} Kubernetes namespace '${PREFIX}-traderx-prod-$region' not found"
      fi
    done
    ;;

  4)
    echo "Testing Stage 4: Push-Upgrade"
    echo "Concept: Propagate base changes while preserving customizations"
    echo ""

    test_section "ConfigHub Structure"
    check_space "${PREFIX}-traderx-base"
    for region in us eu asia; do
      check_space "${PREFIX}-traderx-prod-$region"
      check_upstream "trade-service" "${PREFIX}-traderx-prod-$region"
    done

    test_section "Regional Customizations Preserved"
    check_replicas "trade-service" "${PREFIX}-traderx-prod-us" "3"
    check_replicas "trade-service" "${PREFIX}-traderx-prod-eu" "5"
    check_replicas "trade-service" "${PREFIX}-traderx-prod-asia" "2"

    echo ""
    echo "To test push-upgrade functionality:"
    echo "  1. Update base: cub unit update trade-service --space ${PREFIX}-traderx-base --patch '{...}'"
    echo "  2. Check tree: cub unit tree --node=space trade-service --space '*'"
    echo "  3. Push upgrade: cub unit update --upgrade --patch --space '${PREFIX}-traderx-prod-*'"
    echo "  4. Verify replicas preserved after upgrade"
    ;;

  5)
    echo "Testing Stage 5: Find and Fix (Bulk Operations)"
    echo "Concept: WHERE clauses for bulk operations"
    echo ""

    test_section "Query Operations"
    echo "Testing WHERE clause queries..."

    # Test 1: Find all trade-service units
    local count=$(cub unit list --space "*" --where "Slug = 'trade-service'" 2>/dev/null | grep -c "trade-service" || echo "0")
    if [[ "$count" -gt 0 ]]; then
      test_passed "Found $count trade-service units across spaces"
    else
      test_failed "Found trade-service units" "No units found"
    fi

    # Test 2: Find production units
    count=$(cub unit list --space "*" --where "Space.Slug LIKE '%prod%'" 2>/dev/null | grep -c "^" || echo "0")
    if [[ "$count" -gt 0 ]]; then
      test_passed "Found $count production units"
    else
      test_failed "Found production units" "No units found"
    fi

    echo ""
    echo "Bulk operation examples:"
    echo "  Scale all regions: cub unit update --space '*' --where \"Slug = 'trade-service'\" --patch '{\"spec\":{\"replicas\":3}}'"
    echo "  Find old versions: cub unit list --space '*' --where \"Data CONTAINS 'image:v1'\""
    ;;

  6)
    echo "Testing Stage 6: Atomic Updates (Changesets)"
    echo "Concept: Atomic multi-service updates"
    echo ""

    test_section "Structure Check"
    for region in us eu asia; do
      check_unit "reference-data" "${PREFIX}-traderx-prod-$region"
      check_unit "trade-service" "${PREFIX}-traderx-prod-$region"
    done

    echo ""
    echo "To test changesets:"
    echo "  1. Create: cub changeset create market-data-v2"
    echo "  2. Add changes: cub unit update reference-data --space ${PREFIX}-traderx-prod-us --patch '{...}'"
    echo "  3. Add more: cub unit update trade-service --space ${PREFIX}-traderx-prod-us --patch '{...}'"
    echo "  4. Apply atomic: cub changeset apply market-data-v2"
    ;;

  7)
    echo "Testing Stage 7: Complete System"
    echo "Concept: Full environment hierarchy + lateral promotion"
    echo ""

    test_section "ConfigHub Structure - Base"
    check_space "${PREFIX}-traderx-base"

    test_section "ConfigHub Structure - Environments"
    for env in dev staging; do
      check_space "${PREFIX}-traderx-$env"
      check_unit "reference-data" "${PREFIX}-traderx-$env"
      check_unit "trade-service" "${PREFIX}-traderx-$env"
    done

    test_section "ConfigHub Structure - Regions"
    for region in us eu asia; do
      check_space "${PREFIX}-traderx-prod-$region"
      check_unit "reference-data" "${PREFIX}-traderx-prod-$region"
      check_unit "trade-service" "${PREFIX}-traderx-prod-$region"
    done

    echo ""
    echo "To test lateral promotion:"
    echo "  1. Make emergency fix in EU: cub run set-env-var --env-var CIRCUIT_BREAKER=true --unit trade-service --space ${PREFIX}-traderx-prod-eu"
    echo "  2. Check revision: cub revision list trade-service --space ${PREFIX}-traderx-prod-eu --limit 3"
    echo "  3. Lateral promote to Asia: cub unit update trade-service --space ${PREFIX}-traderx-prod-asia --merge-unit ${PREFIX}-traderx-prod-eu/trade-service"
    ;;

  *)
    echo "Usage: $0 [stage]"
    echo "Stages: 1-7"
    exit 1
    ;;
esac

# Print summary
echo ""
echo "================================="
echo -e "${BLUE}Test Summary${NC}"
echo "================================="
echo "Total tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
  echo "Failed: $TESTS_FAILED"
fi
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}🎉 All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some tests failed${NC}"
  exit 1
fi
