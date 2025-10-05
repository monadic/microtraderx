# MicroTraderX Quick Start

## Two Ways to Run

### Option 1: Run All Stages Sequentially
```bash
# Stage by stage progression
./stages/stage1-hello-traderx.sh
./stages/stage2-three-envs.sh
./stages/stage3-three-regions.sh
./stages/stage4-push-upgrade.sh
./stages/stage5-find-and-fix.sh
./stages/stage6-atomic-updates.sh
./stages/stage7-emergency-bypass.sh
```

### Option 2: Jump to Any Stage
```bash
# Setup structure for stage 3
./setup-structure 3

# Deploy stage 3
./deploy 3

# Validate
./test/validate.sh 3
```

## Stage Overview

| Stage | What You Learn |
|-------|----------------|
| 1 | Spaces, Units, Workers |
| 2 | Environments as Spaces |
| 3 | Regional Scale Customization |
| 4 | Push-Upgrade Pattern |
| 5 | Find and Fix (SQL WHERE) |
| 6 | Atomic Changesets |
| 7 | Emergency Bypass |

## Files Created

```
microtraderx/
├── README.md              # The essence
├── QUICKSTART.md          # This file
├── setup-structure        # Creates ConfigHub structure
├── deploy                 # Deploys to Kubernetes
├── k8s/                   # Kubernetes manifests
│   ├── namespace.yaml
│   ├── reference-data.yaml
│   └── trade-service.yaml
├── stages/                # Individual stage scripts
│   ├── stage1-hello-traderx.sh
│   ├── stage2-three-envs.sh
│   ├── stage3-three-regions.sh
│   ├── stage4-push-upgrade.sh
│   ├── stage5-find-and-fix.sh
│   ├── stage6-atomic-updates.sh
│   └── stage7-emergency-bypass.sh
└── test/
    └── validate.sh        # Verify structure
```

## Key Patterns

### The Two-Script Pattern
Every ConfigHub project needs just two scripts:

1. **setup-structure** - Creates spaces, units, relationships (ConfigHub only)
2. **deploy** - Makes it real in Kubernetes (ConfigHub worker + apply)

### Regional Trading Volumes
```bash
# US: NYSE hours (normal volume)
replicas: 3

# EU: London + Frankfurt (peak trading)
replicas: 5

# Asia: Tokyo overnight (low volume)
replicas: 2
```

### Push-Upgrade Magic
```bash
# Update base
cub unit update trade-service --space traderx-base --data new-algorithm.yaml

# Push to all regions (preserves their replica counts!)
cub unit update --upgrade --patch --space 'traderx-prod-*'
```

### Emergency Bypass
```bash
# Normal flow
dev → staging → us → eu → asia

# Emergency (EU bug, Asia opening in 2h)
eu → asia  (skip US testing!)

# Backfill later
eu → us  (when market closed)
```

## Prerequisites

1. **ConfigHub CLI**: `cub upgrade`
2. **ConfigHub Auth**: `cub auth login`
3. **Kubernetes Cluster**: Local (kind/minikube) or remote
4. **jq**: For JSON parsing (optional but recommended)

## Troubleshooting

### Check ConfigHub Structure
```bash
# List all spaces
cub space list

# List units in a space
cub unit list --space traderx-prod-us

# Get unit details
cub unit get trade-service --space traderx-prod-eu --output json | jq .
```

### Check Kubernetes Deployments
```bash
# List deployments
kubectl get deployments -A | grep traderx

# Check specific region
kubectl get all -n traderx-prod-eu

# Verify replica counts
kubectl get deploy trade-service -n traderx-prod-eu -o jsonpath='{.spec.replicas}'
```

### Cleanup
```bash
# Remove all spaces
cub space delete traderx-base
for region in us eu asia; do
  cub space delete traderx-prod-$region
done

# Remove Kubernetes resources
kubectl delete namespace traderx-prod-us traderx-prod-eu traderx-prod-asia
```

## Next Steps

After completing the tutorial:

1. **Read the full README.md** for detailed explanations
2. **Experiment with modifications** - change replica counts, add services
3. **Build your own app** using the same patterns
4. **Add advanced features** when needed:
   - Changesets for atomic operations
   - Triggers for policy enforcement
   - Approvals for production gates
   - Links for cross-app relationships

Start simple. Add complexity only when needed.
