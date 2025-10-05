# MicroTraderX - ConfigHub in 10 Minutes

> **The Essence**: Start simple. Add power only when needed.

## What Is This?

MicroTraderX is a **7-stage tutorial** that teaches ConfigHub by building a simplified trading platform with multi-region deployment. You'll learn ConfigHub's core concepts in **10 minutes** by doing.

## The Two-Script Pattern

Every ConfigHub project needs just two scripts:

```bash
./setup-structure   # Creates ConfigHub structure (spaces, units, relationships)
./deploy           # Makes it real in Kubernetes (workers + apply)
```

That's it. Everything else is details.

## What You'll Learn

| Stage | Time | What You Learn | Key Concept |
|-------|------|----------------|-------------|
| 1 | 2 min | Spaces, Units, Workers | Basic building blocks |
| 2 | 1 min | Environments | Spaces as environments |
| 3 | 2 min | Regional Scale | Real business logic |
| 4 | 2 min | Push-Upgrade | Update base, keep customizations |
| 5 | 1 min | Find and Fix | SQL WHERE clauses |
| 6 | 1 min | Atomic Updates | Changesets for related services |
| 7 | 1 min | Emergency Bypass | Lateral promotion |

**Total: 10 minutes**

## Real-World Scenario

You're building a **global trading platform** with different trading volumes per region:

- **US**: NYSE hours → 3 replicas (normal volume)
- **EU**: London + Frankfurt → 5 replicas (peak trading)
- **Asia**: Tokyo overnight → 2 replicas (low volume)

**The Challenge**: Update the trading algorithm everywhere, but keep regional replica counts.

**ConfigHub Solution**: Push-upgrade pattern preserves local customizations!

## Quick Start

### Option 1: Run All Stages (10 min)
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

### Option 3: Quick Demo (1 min)
```bash
./stages/stage1-hello-traderx.sh
kubectl get all -n traderx
```

## Prerequisites

1. **ConfigHub CLI**: `cub upgrade`
2. **ConfigHub Auth**: `cub auth login`
3. **Kubernetes**: Local (kind/minikube) or remote cluster
4. **jq**: For JSON parsing (optional but recommended)

## Project Structure

```
microtraderx/
├── README.md                # The Essence (main guide)
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

### 1. Regional Customization (Stage 3)
Same service, different scale based on business needs:
```bash
# US: NYSE hours
replicas: 3

# EU: Peak trading (London + Frankfurt)
replicas: 5

# Asia: Overnight trading
replicas: 2
```

### 2. Push-Upgrade Pattern (Stage 4)
Update algorithm everywhere, preserve regional scale:
```bash
# Update base
cub unit update trade-service --space traderx-base --data new-algorithm.yaml

# Push to all regions (keeps their replicas!)
cub unit update --upgrade --patch --space 'traderx-prod-*'
```

### 3. Find and Fix (Stage 5)
SQL queries across all regions:
```bash
# Find high-replica services
cub unit list --space '*' --where "Data CONTAINS 'replicas: 5'"

# Scale down after market close
cub run set-replicas --replicas 2 --space traderx-prod-eu
```

### 4. Atomic Updates (Stage 6)
Related services update together:
```bash
cub changeset create market-data-v2
cub unit update reference-data --patch '{"image":"v2"}'
cub unit update trade-service --patch '{"image":"v2"}'
cub changeset apply market-data-v2  # Both or neither!
```

### 5. Emergency Bypass (Stage 7)
Lateral promotion when you can't wait:
```bash
# Normal flow
dev → staging → us → eu → asia

# Emergency (EU bug, Asia opening in 2h)
eu → asia  (skip US!)

# Backfill later
eu → us  (when market closed)
```

## Documentation

- **README.md**: The Essence - Complete guide with all 7 stages
- **QUICKSTART.md**: Quick start guide with troubleshooting
- **TESTING.md**: Testing guide with manual scenarios and CI/CD
- **PROJECT_SUMMARY.md**: This overview

## Why This Matters

**Traditional Tools**:
- Change base = lose customizations
- Update regions = edit 3 files manually
- Find problems = grep everything
- Emergency fix = follow the process

**ConfigHub**:
- Change base = keep customizations (push-upgrade)
- Update regions = one command (WHERE clause)
- Find problems = SQL query
- Emergency fix = lateral promotion

## The Philosophy

> Start simple. Add power only when needed.

This tutorial teaches ConfigHub's core concepts without overwhelming complexity:

1. **Stage 1**: Just the basics (space + unit + worker)
2. **Stage 2**: Add environments when you need them
3. **Stage 3**: Add regional scale when business requires it
4. **Stage 4**: Add inheritance when you need to push updates
5. **Stage 5**: Add bulk operations when you need to find/fix
6. **Stage 6**: Add changesets when you need atomicity
7. **Stage 7**: Add emergency bypass when you need flexibility

Each feature is introduced **when it solves a real problem**.

## Success Criteria

After completing this tutorial, you should be able to:

- ✅ Create ConfigHub spaces and units
- ✅ Deploy configurations to Kubernetes
- ✅ Manage multiple environments and regions
- ✅ Use push-upgrade to update globally while preserving local changes
- ✅ Query and fix problems across all regions with SQL WHERE
- ✅ Perform atomic multi-service updates
- ✅ Handle emergency scenarios with lateral promotion

## Next Steps

1. **Complete the tutorial**: `./stages/stage1-hello-traderx.sh`
2. **Experiment**: Modify replica counts, add services
3. **Build your own**: Apply these patterns to your apps
4. **Learn more**: Explore advanced features (triggers, approvals, links)

## Contributing

This is a canonical example. Improvements welcome!

- Found a bug? Open an issue
- Have a better example? Submit a PR
- Want to add a stage? Let's discuss

## License

This tutorial is open source. Use it to learn, teach, and build.

---

**Remember**: Two scripts rule everything. Start simple. Add power only when needed.
