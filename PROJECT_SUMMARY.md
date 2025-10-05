# MicroTraderX Project Summary

## Overview

MicroTraderX is a 7-stage tutorial that demonstrates ConfigHub concepts through building a simplified trading platform with multi-region deployment.

## Core Implementation Pattern

ConfigHub projects use two primary scripts:

```bash
./setup-structure   # Creates ConfigHub structure (spaces, units, relationships)
./deploy           # Deploys to Kubernetes (workers + apply)
```

## Tutorial Stages

| Stage | Topic | Key Concept |
|-------|-------|-------------|
| 1 | Spaces, Units, Workers | Basic building blocks |
| 2 | Environments | Spaces as environments |
| 3 | Regional Scale | Business-driven configuration |
| 4 | Push-Upgrade | Update base, preserve customizations |
| 5 | Find and Fix | SQL WHERE clauses |
| 6 | Atomic Updates | Changesets for related services |
| 7 | Emergency Bypass | Lateral promotion |

## Example Scenario

The tutorial uses a global trading platform with region-specific scaling:

- US: 3 replicas (NYSE hours, normal volume)
- EU: 5 replicas (London + Frankfurt, peak trading)
- Asia: 2 replicas (Tokyo overnight, low volume)

Challenge: Update the trading algorithm globally while preserving regional replica counts.

Solution: ConfigHub's push-upgrade pattern preserves local customizations during base updates.

## Quick Start

### Option 1: Run All Stages
```bash
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
./setup-structure 3    # Setup stage 3
./deploy 3             # Deploy stage 3
./test/validate.sh 3   # Validate
```

### Option 3: Quick Demo
```bash
./stages/stage1-hello-traderx.sh
kubectl get all -n traderx
```

## Prerequisites

1. ConfigHub CLI: `cub upgrade`
2. ConfigHub Auth: `cub auth login`
3. Kubernetes: Local (kind/minikube) or remote cluster
4. jq: For JSON parsing (optional)

## Project Structure

```
microtraderx/
├── README.md                # Main tutorial guide
├── QUICKSTART.md            # Quick start guide
├── TESTING.md               # Testing guide
├── PROJECT_SUMMARY.md       # This file
├── setup-structure          # Main setup script
├── deploy                   # Main deploy script
├── k8s/                     # Kubernetes manifests
│   ├── namespace.yaml
│   ├── reference-data.yaml
│   └── trade-service.yaml
├── stages/                  # Individual stage scripts
│   ├── stage1-hello-traderx.sh
│   ├── stage2-three-envs.sh
│   ├── stage3-three-regions.sh
│   ├── stage4-push-upgrade.sh
│   ├── stage5-find-and-fix.sh
│   ├── stage6-atomic-updates.sh
│   └── stage7-emergency-bypass.sh
└── test/
    └── validate.sh          # Validation script
```

## Key Features Demonstrated

### Regional Customization (Stage 3)
Same service, different scale based on business needs:
```bash
# US: NYSE hours
replicas: 3

# EU: Peak trading (London + Frankfurt)
replicas: 5

# Asia: Overnight trading
replicas: 2
```

### Push-Upgrade Pattern (Stage 4)
Update algorithm globally, preserve regional scale:
```bash
# Update base
cub unit update trade-service --space traderx-base --data new-algorithm.yaml

# Push to all regions (preserves replicas)
cub unit update --upgrade --patch --space 'traderx-prod-*'
```

### Find and Fix (Stage 5)
SQL queries across all regions:
```bash
# Find high-replica services
cub unit list --space '*' --where "Data CONTAINS 'replicas: 5'"

# Scale down after market close
cub run set-replicas --replicas 2 --space traderx-prod-eu
```

### Atomic Updates (Stage 6)
Related services update together:
```bash
cub changeset create market-data-v2
cub unit update reference-data --patch '{"image":"v2"}'
cub unit update trade-service --patch '{"image":"v2"}'
cub changeset apply market-data-v2  # Both or neither
```

### Emergency Bypass (Stage 7)
Lateral promotion for critical situations:
```bash
# Normal flow
dev → staging → us → eu → asia

# Emergency (EU bug, Asia opening soon)
eu → asia  # Skip US

# Backfill later
eu → us  # When market closed
```

## Documentation

- README.md: Complete tutorial with all 7 stages
- QUICKSTART.md: Quick start guide with troubleshooting
- TESTING.md: Testing guide with manual scenarios and CI/CD
- PROJECT_SUMMARY.md: This overview

## Tutorial Design

The tutorial introduces ConfigHub concepts progressively:

1. Stage 1: Basic concepts (space, unit, worker)
2. Stage 2: Environment management
3. Stage 3: Regional scaling based on business requirements
4. Stage 4: Inheritance for global updates
5. Stage 5: Bulk operations using WHERE clauses
6. Stage 6: Atomic updates with changesets
7. Stage 7: Emergency scenarios with lateral promotion

Each feature is introduced when it addresses a specific use case.

## Objectives

After completing this tutorial, you should be able to:

- Create ConfigHub spaces and units
- Deploy configurations to Kubernetes
- Manage multiple environments and regions
- Use push-upgrade to update globally while preserving local changes
- Query and fix configurations across regions with SQL WHERE clauses
- Perform atomic multi-service updates
- Handle emergency scenarios with lateral promotion

## Next Steps

1. Complete the tutorial: `./stages/stage1-hello-traderx.sh`
2. Experiment: Modify replica counts, add services
3. Apply these patterns to your applications
4. Explore advanced features: triggers, approvals, links

## Contributing

This tutorial serves as a canonical ConfigHub example. Contributions are welcome:

- Bug reports: Open an issue
- Improvements: Submit a PR
- New stages: Open an issue for discussion

## License

This tutorial is open source.
