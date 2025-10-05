# ConfigHub in 10 Minutes

A progressive tutorial demonstrating ConfigHub's core features through TraderX deployment.

---

## 📚 Documentation

- **[VISUAL-GUIDE.md](VISUAL-GUIDE.md)** - Stage-by-stage visual progression with ASCII diagrams
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture, inheritance flow, and deployment patterns
- **[MODULAR-APPS.md](MODULAR-APPS.md)** - Extend MicroTraderX with DevOps applications (Stages 8-10)
- **[QUICKSTART.md](QUICKSTART.md)** - Quick start guide and troubleshooting
- **[TESTING.md](TESTING.md)** - Testing guide and validation
- **[DOCS-MAP.md](DOCS-MAP.md)** - Documentation index and reading paths by persona

For visual learners: [VISUAL-GUIDE.md](VISUAL-GUIDE.md) provides diagrams for each stage.

For navigation help: [DOCS-MAP.md](DOCS-MAP.md) organizes documentation by role and topic.

---

## ConfigHub Architecture
> ConfigHub is a configuration database with a state machine. Every change is tracked, queryable, and reversible. ConfigHub maintains the desired state as the source of truth; Kubernetes reflects the executed state.
> — Brian Grant, ConfigHub inventor

## Core Implementation Pattern

```bash
./setup-structure   # Creates spaces, units, relationships
./deploy           # Deploys to Kubernetes via Workers
```

These two scripts encapsulate the essential ConfigHub workflow.

---

## Stage 1: Hello TraderX (2 min)

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

## Stage 2: Three Environments (3 min)

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

## Stage 3: Three Regions, Three Trading Volumes (5 min)

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

**Key concept**: Regional customization based on actual business requirements.

---

## Stage 4: Push-Upgrade Pattern

Propagate base changes while preserving regional customizations.

```bash
# Create base + regions with inheritance
cub space create traderx-base
cub unit create trade-service --space traderx-base \
  --data trade-service-v1.yaml

for region in us eu asia; do
  cub unit create trade-service --space traderx-prod-$region \
    --upstream-unit traderx-base/trade-service  # Magic link!
done

# Regions already customized (from Stage 3)
# EU has 5 replicas for peak trading
# Asia has 2 for overnight

# Critical update: New trade algorithm v2
cub unit update trade-service --space traderx-base \
  --data trade-service-v2.yaml  # New algorithm!

# Push upgrade (preserves regional replicas!)
cub unit update --upgrade --patch --space "traderx-prod-*"
```

```
Before upgrade:
traderx-base/
└── trade-service (v1: old algorithm)
    ├── prod-us/trade-service (v1, replicas: 3)
    ├── prod-eu/trade-service (v1, replicas: 5)
    └── prod-asia/trade-service (v1, replicas: 2)

After upgrade:
traderx-base/
└── trade-service (v2: NEW algorithm)
    ├── prod-us/trade-service (v2, replicas: 3) ✓
    ├── prod-eu/trade-service (v2, replicas: 5) ✓  # Kept 5!
    └── prod-asia/trade-service (v2, replicas: 2) ✓  # Kept 2!
```

**Key concept**: Inheritance with merge capabilities. Base updates propagate while local overrides persist.

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

# Asia market opens in 2 hours, requires fix before opening
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

```
Structure (setup-structure):
traderx-base/                  # Shared configs
├── reference-data-base       # Market data config
├── trade-service-base        # Trading engine config
└── web-gui-base             # UI config

traderx-dev/                  # Development
├── reference-data (→base)
├── trade-service (→base)
└── web-gui (→base)

traderx-prod-us/              # US production
├── trade-service (replicas: 3)  # NYSE volume

traderx-prod-eu/              # EU production
├── trade-service (replicas: 5)  # Peak trading

traderx-prod-asia/            # Asia production
├── trade-service (replicas: 2)  # Overnight

Operations (deploy):
cub worker install           # One per cluster
cub unit apply              # Deploy everything
cub unit update --upgrade --patch  # Push algorithm updates
```

---

## Comparison with Traditional Tools

**Traditional Tools**:
- Updating base configurations overwrites customizations
- Regional updates require editing multiple files
- Finding configuration issues requires manual search
- Emergency fixes must follow standard promotion flow

**ConfigHub**:
- Push-upgrade preserves customizations during base updates
- WHERE clauses enable bulk operations across regions
- SQL-like queries locate configurations
- Lateral promotion bypasses standard flow when needed

---

## The Two Scripts (Complete TraderX)

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

---

## Visual Learning Resources

### Architecture Diagrams
See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed visual diagrams:
- Complete system architecture (ConfigHub → Kubernetes)
- 3-region deployment topology (US, EU, Asia)
- Inheritance flow and upstream/downstream relationships
- Push-upgrade pattern (before/after)
- Emergency lateral promotion flow
- Multi-cluster deployment architecture

### Stage-by-Stage Progression
See [VISUAL-GUIDE.md](VISUAL-GUIDE.md) for visual progression through all 7 stages:
- Stage 1: Hello TraderX (spaces + units + workers)
- Stage 2: Three Environments (dev → staging → prod)
- Stage 3: Three Regions (regional scaling: 3, 5, 2 replicas)
- Stage 4: Push-Upgrade (inherit + propagate + preserve)
- Stage 5: Find and Fix (SQL-like WHERE clauses)
- Stage 6: Atomic Updates (changesets for consistency)
- Stage 7: Emergency Bypass (lateral promotion for critical fixes)

Each stage includes:
- ASCII art diagrams showing the structure
- Before/after visualizations
- Command examples
- Key concepts
- Real-world scenarios

**Recommended learning path**:
1. Read this README for overview (10 minutes)
2. Review [VISUAL-GUIDE.md](VISUAL-GUIDE.md) to see each stage (15 minutes)
3. Study [ARCHITECTURE.md](ARCHITECTURE.md) for technical details (20 minutes)
4. Run the stages yourself with [QUICKSTART.md](QUICKSTART.md) (10 minutes)