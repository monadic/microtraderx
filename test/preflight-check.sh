#!/bin/bash
# Pre-flight check for MicroTraderX tutorial
# Validates environment before running tutorial

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}✈️  MicroTraderX Pre-Flight Check${NC}"
echo "================================"
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

check_passed() {
  ((CHECKS_PASSED++))
  echo -e "${GREEN}✓${NC} $1"
}

check_failed() {
  ((CHECKS_FAILED++))
  echo -e "${RED}✗${NC} $1"
  echo -e "  ${RED}$2${NC}"
}

check_warning() {
  ((WARNINGS++))
  echo -e "${YELLOW}⚠${NC} $1"
  echo -e "  ${YELLOW}$2${NC}"
}

# Check 1: cub CLI installed
echo "Checking CLI tools..."
if command -v cub &>/dev/null; then
  version=$(cub version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
  check_passed "cub CLI installed (version: $version)"
else
  check_failed "cub CLI installed" "Install with: cub upgrade"
fi

# Check 2: kubectl installed
if command -v kubectl &>/dev/null; then
  version=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' || echo "unknown")
  check_passed "kubectl installed ($version)"
else
  check_failed "kubectl installed" "Install kubectl"
fi

# Check 3: jq installed
if command -v jq &>/dev/null; then
  check_passed "jq installed"
else
  check_warning "jq installed" "Optional but recommended for JSON parsing"
fi

echo ""

# Check 4: ConfigHub authentication
echo "Checking ConfigHub authentication..."
if cub auth status &>/dev/null; then
  user=$(cub auth status 2>/dev/null | grep "User:" | awk '{print $2}' || echo "unknown")
  check_passed "ConfigHub authenticated (user: $user)"
else
  check_failed "ConfigHub authenticated" "Run: cub auth login"
fi

echo ""

# Check 5: Kubernetes cluster access
echo "Checking Kubernetes cluster..."
if kubectl cluster-info &>/dev/null; then
  cluster=$(kubectl config current-context 2>/dev/null || echo "unknown")
  check_passed "Kubernetes cluster accessible ($cluster)"

  # Check node status
  nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$nodes" -gt 0 ]]; then
    check_passed "Kubernetes cluster has $nodes node(s)"
  else
    check_warning "Kubernetes cluster nodes" "No nodes found"
  fi
else
  check_failed "Kubernetes cluster accessible" "Start cluster: kind create cluster"
fi

echo ""

# Check 6: Required files exist
echo "Checking project files..."
required_files=(
  "setup-structure"
  "deploy"
  "k8s/reference-data.yaml"
  "k8s/trade-service.yaml"
  "k8s/namespace-base.yaml"
  "bin/get-prefix"
)

for file in "${required_files[@]}"; do
  if [[ -f "$file" ]]; then
    check_passed "File exists: $file"
  else
    check_failed "File exists: $file" "File not found"
  fi
done

echo ""

# Check 7: Scripts are executable
echo "Checking permissions..."
if [[ -x "setup-structure" ]]; then
  check_passed "setup-structure is executable"
else
  check_failed "setup-structure is executable" "Run: chmod +x setup-structure"
fi

if [[ -x "deploy" ]]; then
  check_passed "deploy is executable"
else
  check_failed "deploy is executable" "Run: chmod +x deploy"
fi

if [[ -x "bin/get-prefix" ]]; then
  check_passed "bin/get-prefix is executable"
else
  check_failed "bin/get-prefix is executable" "Run: chmod +x bin/get-prefix"
fi

echo ""

# Check 8: Docker images accessible
echo "Checking Docker images..."
if docker pull ghcr.io/finos/traderx/reference-data:latest &>/dev/null || kubectl get pods &>/dev/null; then
  check_passed "Docker registry accessible"
else
  check_warning "Docker registry accessible" "Images may not be pre-cached"
fi

echo ""

# Check 9: Previous installation
echo "Checking for previous installations..."
PREFIX=$(bin/get-prefix 2>/dev/null || echo "")
if [[ -n "$PREFIX" ]]; then
  spaces=$(cub space list 2>/dev/null | grep -c "^${PREFIX}-traderx" || echo "0")
  if [[ "$spaces" -gt 0 ]]; then
    check_warning "Previous installation detected" "Found $spaces spaces with prefix '$PREFIX'. Run './test/cleanup.sh' to clean up."
  else
    check_passed "No previous installation found"
  fi
else
  check_passed "No previous installation found"
fi

echo ""
echo "================================"
echo -e "${BLUE}Summary${NC}"
echo "================================"
echo -e "${GREEN}Passed: $CHECKS_PASSED${NC}"
if [[ $CHECKS_FAILED -gt 0 ]]; then
  echo -e "${RED}Failed: $CHECKS_FAILED${NC}"
else
  echo "Failed: $CHECKS_FAILED"
fi
if [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
fi
echo ""

if [[ $CHECKS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✅ Ready to run MicroTraderX tutorial!${NC}"
  echo ""
  echo "Quick start:"
  echo "  ./setup-structure 1   # Create ConfigHub structure"
  echo "  ./deploy 1           # Deploy to Kubernetes"
  echo "  ./test/run-stage-test.sh 1  # Validate"
  exit 0
else
  echo -e "${RED}❌ Prerequisites not met${NC}"
  echo ""
  echo "Fix the failed checks above before continuing."
  exit 1
fi
