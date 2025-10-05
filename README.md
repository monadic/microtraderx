# ConfigHub Tutorial

WARNING - still testing this.  

A 7-stage tutorial that demonstrates ConfigHub concepts through building a simplified trading platform with multi-region deployment.

---

## 📚 Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Quick start guide and troubleshooting
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture, inheritance flow, and deployment patterns
- **[VISUAL-GUIDE.md](VISUAL-GUIDE.md)** - ASCII diagrams for each stage
- **[TESTING.md](TESTING.md)** - Testing guide and validation
- **[DOCS-MAP.md](DOCS-MAP.md)** - Documentation index and topic/persona navigation
- **[MODULAR-APPS.md](MODULAR-APPS.md)** - Extend MicroTraderX with "devops" apps

---

## Prerequisites

1. ConfigHub CLI: `cub upgrade`
2. ConfigHub Auth: `cub auth login`
3. Kubernetes: Local (kind/minikube) or remote cluster
4. jq: For JSON parsing (optional)

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

## Project Structure

```
microtraderx/
├── README.md                # This tutorial guide
├── QUICKSTART.md            # Quick start guide
├── TESTING.md               # Testing guide
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

---

## ConfigHub Architecture
> ConfigHub is a configuration database with a state machine. Every change is tracked, queryable, and reversible. ConfigHub maintains the desired state as the source of truth; Kubernetes reflects the executed state.

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

---

## Stage 1: Hello TraderX

```bash
# setup-structure
cub space create traderx
cub unit create reference-data --space traderx --data reference-data.yaml

# deploy
cub worker install worker --space traderx --wait
cub unit apply reference-data --space traderx
```

```
traderx/
└── reference-data (market data service)
```

**Key concept**: Spaces contain units. Workers deploy them to Kubernetes.

---

## Stage 2: Three Environments

```bash
# setup-structure
for env in dev staging prod; do
  cub space create traderx-$env
  cub unit copy reference-data --from traderx --to traderx-$env
done

# deploy (just prod)
cub worker install worker --space traderx-prod --wait
cub unit apply reference-data --space traderx-prod
```

```
traderx-dev/
├── reference-data (copied)
traderx-staging/
├── reference-data (copied)
traderx-prod/
└── reference-data (deployed) ✓
```

**Key concept**: Each environment is a separate space. Copy operations promote configurations.

---

## Stage 3: Three Regions, Three Trading Volumes

Deploy the same platform with region-specific scaling based on trading volume.

```bash
# setup-structure
# Now add trade-service (handles actual trades)
cub unit create trade-service --space traderx-prod --data trade-service.yaml

for region in us eu asia; do
  cub space create traderx-prod-$region
  cub unit copy reference-data --from traderx-prod --to traderx-prod-$region
  cub unit copy trade-service --from traderx-prod --to traderx-prod-$region
done

# Customize per region based on trading volume!
cub unit update trade-service --space traderx-prod-us \
  --patch '{"replicas": 3}'    # NYSE hours = normal volume

cub unit update trade-service --space traderx-prod-eu \
  --patch '{"replicas": 5}'    # London + Frankfurt = high volume

cub unit update trade-service --space traderx-prod-asia \
  --patch '{"replicas": 2}'    # Tokyo overnight = low volume

# deploy all regions
for region in us eu asia; do
  cub unit apply --space traderx-prod-$region --where "*"
done
```

```
traderx-prod-us/
├── reference-data (replicas: 1)
└── trade-service (replicas: 3) ✓  # NYSE hours

traderx-prod-eu/
├── reference-data (replicas: 1)
└── trade-service (replicas: 5) ✓  # Peak trading!

traderx-prod-asia/
├── reference-data (replicas: 1)
└── trade-service (replicas: 2) ✓  # Overnight trading
```

**Key concept**: Each region is a variant - a customized copy of the same base configuration. Regional units will later inherit from base using `--upstream-unit`.

---

## Stage 4: Push-Upgrade Pattern

Propagate base changes while preserving regional customizations.

**Why base configurations exist:**
- Update application version in one place → flows to all variants
- Regional customizations (replicas) preserved during upgrades
- Single source of truth for shared configuration
- Without base: Must update each region manually, risking inconsistency

```bash
# Create base + regions with inheritance
cub space create traderx-base
cub unit create trade-service --space traderx-base \
  --data trade-service-v1.yaml

for region in us eu asia; do
  cub unit create trade-service --space traderx-prod-$region \
    --upstream-unit traderx-base/trade-service  # Creates variants
done

# Regions already customized (from Stage 3)
# EU has 5 replicas for peak trading
# Asia has 2 for overnight

# Visualize variant hierarchy
cub unit tree --node=space trade-service --space "*"

# Critical update: New trade algorithm v2
cub unit update trade-service --space traderx-base \
  --data trade-service-v2.yaml  # New algorithm!

# Check which variants need upgrading
cub unit tree --node=space trade-service --space "*" \
  --columns Space.Slug,UpgradeNeeded

# Dry-run to preview changes before applying
cub unit update --dry-run --upgrade --patch --space "traderx-prod-us"

# Push upgrade (preserves regional replicas!)
cub unit update --upgrade --patch --space "traderx-prod-*"
```

Tree output shows variant hierarchy:
```
NODE                  UNIT            UPGRADE-NEEDED
└── traderx-base      trade-service
    ├── traderx-prod-us    trade-service   Yes
    ├── traderx-prod-eu    trade-service   Yes
    └── traderx-prod-asia  trade-service   Yes
```

After upgrade, variants preserve customizations:
```
traderx-base/trade-service (v2: NEW algorithm)
├── prod-us/trade-service (v2, replicas: 3) ✓
├── prod-eu/trade-service (v2, replicas: 5) ✓  # Kept 5!
└── prod-asia/trade-service (v2, replicas: 2) ✓  # Kept 2!
```

**Key concept**: Variants inherit from base via `--upstream-unit`. Upgrade propagates base changes while preserving variant customizations.

---

## Stage 5: Query and Filter Operations

```bash
# Create a reusable filter for high-volume services
cub filter create high-volume-trading Unit \
  --where-field "Data CONTAINS 'replicas:' AND
                 Data NOT LIKE '%replicas: 1%' AND
                 Data NOT LIKE '%replicas: 2%'"

# Now anyone can use this filter without remembering the query!
cub unit list --filter high-volume-trading --space "*"

# Output:
# traderx-prod-us/trade-service (replicas: 3)
# traderx-prod-eu/trade-service (replicas: 5)

# Scale down EU after market close using the filter
cub run set-replicas --replicas 2 \
  --filter high-volume-trading \
  --space "traderx-prod-eu"

# Or find all services using old image version
cub unit list --space "*" \
  --where "Data CONTAINS 'image:' AND Data CONTAINS ':v1'"
```

**Key concept**: SQL-like WHERE clauses work across all spaces. Filters provide reusable query definitions.

---

## Stage 6: Atomic Multi-Service Updates

```bash
# New market data format requires updating both services together

# Changesets coordinate changes across teams and services
cub changeset create market-data-v2  # Supports ownership and approval workflows
cub unit update reference-data --space traderx-prod-us \
  --patch '{"image": "reference-data:v2"}'  # Data team's change
cub unit update trade-service --space traderx-prod-us \
  --patch '{"image": "trade-service:v2"}'   # Trading team's change
cub changeset apply market-data-v2  # Atomic deployment when both teams are ready
```

```
Changeset: market-data-v2
├── reference-data (v1 → v2: owned by data-team)
└── trade-service (v1 → v2: owned by trading-team)
Status: Applied atomically
```

**Key concept**: Changesets ensure related changes deploy together or not at all. Supports team coordination.

---

## Stage 7: Lateral Promotion for Emergency Changes

```bash
# Normal flow: dev → staging → us → eu → asia
# EU discovered critical trading bug at market open

# Emergency fix directly in EU
cub run set-env-var --env-var CIRCUIT_BREAKER=true \
  --unit trade-service --space traderx-prod-eu

# Check revision history - WHO did WHAT and WHEN?
cub revision list trade-service --space traderx-prod-eu --limit 3
# Output:
# Rev 47: 2024-01-16 09:15 UTC | alice@trading.com | set CIRCUIT_BREAKER=true
# Rev 46: 2024-01-15 18:00 UTC | system | scale replicas 5→2 (market close)
# Rev 45: 2024-01-15 08:00 UTC | system | scale replicas 2→5 (market open)

# Asia market opens soon, requires immediate fix
cub unit update trade-service --space traderx-prod-asia \
  --merge-unit traderx-prod-eu/trade-service \
  --merge-base=46 --merge-end=47  # Merge only the emergency fix

# US market closed, backfill later
cub unit update trade-service --space traderx-prod-us \
  --merge-unit traderx-prod-eu/trade-service
```

```
Normal:   dev → staging → us → eu → asia
Emergency:                 eu → asia  (Bypass US)
                           ↓
Backfill:                  us  (After market close)
```

**Key concept**: Lateral promotion enables emergency fixes to bypass normal promotion flow. Full revision history provides audit trail.

---

## Complete System Structure

Variant hierarchy (visualize with `cub unit tree`):
```
NODE                  UNIT            SPACE
└── traderx-base      trade-service   traderx-base
    ├── traderx-prod-us    trade-service   traderx-prod-us    (3 replicas)
    ├── traderx-prod-eu    trade-service   traderx-prod-eu    (5 replicas)
    └── traderx-prod-asia  trade-service   traderx-prod-asia  (2 replicas)
```

Space structure:
```
traderx-base/                  # Base configurations
├── reference-data            # Market data
├── trade-service             # Trading engine
└── web-gui                   # UI

traderx-prod-us/              # US variants
├── reference-data (→base)
├── trade-service (→base, replicas: 3)
└── web-gui (→base)

traderx-prod-eu/              # EU variants
├── trade-service (→base, replicas: 5)

traderx-prod-asia/            # Asia variants
├── trade-service (→base, replicas: 2)

Operations:
cub unit tree --node=space --space "*"        # Visualize hierarchy
cub unit update --upgrade --patch --space "*" # Upgrade all variants
cub unit apply --space "*"                    # Deploy all
```

---

## ConfigHub Comparison with Traditional Tools

**ConfigHub**:
- Updates preserve customizations and don't clobber or surprise
- Bulk operations and other live ops at scale
- Queries instead of hunting through config sprawl
- Lateral promotions instead of chaining dev tools to promote changes 

---

## The Two Scripts

### setup-structure
```bash
#!/bin/bash
# Create base space for shared configs
cub space create traderx-base
cub unit create reference-data --space traderx-base --data reference-data.yaml
cub unit create trade-service --space traderx-base --data trade-service.yaml

# Create regions with inheritance
for region in us eu asia; do
  cub space create traderx-prod-$region
  cub unit create reference-data --space traderx-prod-$region \
    --upstream-unit traderx-base/reference-data
  cub unit create trade-service --space traderx-prod-$region \
    --upstream-unit traderx-base/trade-service
done

# Regional customizations based on trading volume
cub unit update trade-service --space traderx-prod-us --patch '{"replicas": 3}'   # NYSE
cub unit update trade-service --space traderx-prod-eu --patch '{"replicas": 5}'   # Peak
cub unit update trade-service --space traderx-prod-asia --patch '{"replicas": 2}' # Overnight
```

### deploy
```bash
#!/bin/bash
# Install workers (once per cluster)
for region in us eu asia; do
  cub worker install traderx-worker-$region \
    --space traderx-prod-$region --wait
done

# Deploy everything
cub unit apply --space "traderx-prod-*" --where "*"
```

---

## Additional ConfigHub Features

The patterns above demonstrate core ConfigHub functionality. Additional features include:

- **Changesets** - Atomic operations across multiple units (Stage 6)
- **Filters** - Reusable query definitions (Stage 5)
- **Triggers** - Policy enforcement and validation rules
- **Invocations** - Reusable function definitions for standardized operations
- **Links** - Define relationships between units
- **Sets** - Logical grouping of units for bulk operations
- **Cross-Space Inheritance** - Share configurations across space boundaries:
  ```bash
  cub unit create monitoring --space traderx-prod-us \
    --upstream-unit platform-base/monitoring-standard
  ```

ConfigHub maintains complete change history with rollback capabilities at the unit level.

ConfigHub has an SDK and integrations with tools like Helm.

---

## What to read

1. Read this README for overview
2. Review [VISUAL-GUIDE.md](VISUAL-GUIDE.md) to see each stage
3. Study [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
4. Run the stages yourself with [QUICKSTART.md](QUICKSTART.md)

### Visual Progression
See [VISUAL-GUIDE.md](VISUAL-GUIDE.md) for command examples and ASCII before/after diagrams:
- Stage 1: Hello TraderX
- Stage 2: Three Environments
- Stage 3: Three Regions
- Stage 4: Push-Upgrade
- Stage 5: Find and Fix
- Stage 6: Atomic Updates
- Stage 7: Emergency Bypass

### Architecture Diagrams
See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed visual diagrams:
- Complete system architecture (ConfigHub → Kubernetes)
- 3-region deployment topology (US, EU, Asia)
- Inheritance flow and upstream/downstream relationships
- Push-upgrade pattern (before/after)
- Emergency lateral promotion flow
- Multi-cluster deployment architecture

- Stage 7: Emergency Bypass

Each stage includes:
- ASCII art diagrams showing the structure
- Before/after visualizations
- Command examples
- Key concepts
- Real-world scenarios

**Recommended learning path**:
1. Read this README for overview
2. Review [VISUAL-GUIDE.md](VISUAL-GUIDE.md) to see each stage
3. Study [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
4. Run the stages yourself with [QUICKSTART.md](QUICKSTART.md)

---

## Learning Objectives

After completing this tutorial, you should be able to:

- Create ConfigHub spaces and units
- Deploy configurations to Kubernetes
- Manage multiple environments and regions
- Use push-upgrade to update globally while preserving local changes
- Query and fix configurations across regions with SQL WHERE clauses
- Perform atomic multi-service updates
- Handle emergency scenarios with lateral promotion
