# ConfigHub in 10 Minutes: The Essence

Start simple. Add power only when needed.

---

## 📚 Documentation

- **[VISUAL-GUIDE.md](VISUAL-GUIDE.md)** - Stage-by-stage visual progression with ASCII diagrams
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture, inheritance flow, and deployment patterns
- **[MODULAR-APPS.md](MODULAR-APPS.md)** ⭐ - **NEW!** Extend MicroTraderX with DevOps apps (Stages 8-10)
- **[QUICKSTART.md](QUICKSTART.md)** - Quick start guide and troubleshooting
- **[TESTING.md](TESTING.md)** - Testing guide and validation
- **[DOCS-MAP.md](DOCS-MAP.md)** - Documentation index and reading paths by persona

**New to ConfigHub?** Start with [VISUAL-GUIDE.md](VISUAL-GUIDE.md) to see the progression through all 7 stages with clear diagrams.

**Not sure where to start?** See [DOCS-MAP.md](DOCS-MAP.md) for recommended reading paths based on your role (learner, developer, architect, tester).

---

## The Core Pattern: Two Scripts Rule Everything

```bash
./setup-structure   # Creates spaces, units, relationships
./deploy           # Makes it real in Kubernetes
```

That's it. Everything else is details.

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

✅ **Essence**: Space contains units. Worker deploys them.

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

✅ **Essence**: Spaces are environments. Copy promotes config.

---

## Stage 3: Three Regions, Three Trading Volumes (5 min)

**The Power Move**: Same trading platform, different scale per region.

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

✅ **Essence**: Each region has custom scale. Real business logic!

---

## Stage 4: Push Changes, Keep Regional Scale

**The Killer Feature**: Update base → flows everywhere, keeps local changes.

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

✅ **Essence**: Algorithm updated everywhere. Regional scale preserved. Magic!

---

## Stage 5: Find and Fix Problems Everywhere

```bash
# Market closed in EU, scale down all high-replica services
cub unit list --space "*" \
  --where "Space.Slug LIKE '%prod-eu%' AND Data CONTAINS 'replicas: 5'"

# Output:
# traderx-prod-eu/trade-service (replicas: 5)

# Scale down after market close
cub run set-replicas --replicas 2 \
  --where "Data CONTAINS 'replicas: 5'" \
  --space "traderx-prod-eu"

# Or find all services using old image version
cub unit list --space "*" \
  --where "Data CONTAINS 'image:' AND Data CONTAINS ':v1'"
```

✅ **Essence**: SQL queries across regions. Fix problems globally.

---

## Stage 6: Atomic Multi-Service Updates

```bash
# New market data format requires updating BOTH services
# They MUST deploy together or trading breaks!

cub changeset create market-data-v2
cub unit update reference-data --space traderx-prod-us \
  --patch '{"image": "reference-data:v2"}'  # New format
cub unit update trade-service --space traderx-prod-us \
  --patch '{"image": "trade-service:v2"}'   # Compatible version
cub changeset apply market-data-v2  # Both or neither!
```

```
Changeset: market-data-v2
├── reference-data (v1 → v2: new format)
└── trade-service (v1 → v2: reads new format)
Apply: ✓ Atomic! No broken trades!
```

✅ **Essence**: Related services update together. No partial failures.

---

## Stage 7: Emergency Bypass (Lateral Promotion)

```bash
# Normal flow: dev → staging → us → eu → asia
# But EU discovered critical trading bug at market open!

# Emergency fix directly in EU
cub run set-env-var --env-var CIRCUIT_BREAKER=true \
  --unit trade-service --space traderx-prod-eu

# Asia market opens in 2 hours, need fix NOW (skip US!)
cub unit update trade-service --space traderx-prod-asia \
  --merge-unit traderx-prod-eu/trade-service

# US market closed, backfill later
cub unit update trade-service --space traderx-prod-us \
  --merge-unit traderx-prod-eu/trade-service
```

```
Normal:   dev → staging → us → eu → asia
Emergency:                 eu → asia  (Fix in 2 hours!)
                           ↓
Backfill:                  us  (When market closed)
```

✅ **Essence**: Emergency fix when Asia can't wait for US testing.

---

## The Complete System (30 seconds to understand)

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

## Why This Matters: The 10-Second Pitch

**Traditional Tools**:
- Change base = lose customizations
- Update regions = edit 3 files
- Find problems = grep everything
- Emergency fix = follow the process

**ConfigHub**:
- Change base = keep customizations (push-upgrade)
- Update regions = one command (WHERE)
- Find problems = SQL query
- Emergency fix = lateral promotion

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

## Learn More When You Need It

Start here. When you hit limits, add:
- **Changesets** for atomic operations
- **Triggers** for policy enforcement
- **Approvals** for production gates
- **Links** for cross-app relationships
- **Sets** for logical grouping

But not before you need them. Simplicity first.

---

## Visual Learning Resources

### 📊 Architecture Diagrams
See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed visual diagrams showing:
- Complete system architecture (ConfigHub → Kubernetes)
- 3-region deployment topology (US, EU, Asia)
- Inheritance flow and upstream/downstream relationships
- Push-upgrade pattern (before/after)
- Emergency lateral promotion flow
- Multi-cluster deployment architecture

### 📈 Stage-by-Stage Progression
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
- Key learning points
- Real-world scenarios

**Recommended learning path**:
1. Read this README for the essence (10 minutes)
2. Review [VISUAL-GUIDE.md](VISUAL-GUIDE.md) to see each stage (15 minutes)
3. Study [ARCHITECTURE.md](ARCHITECTURE.md) for deep dive (20 minutes)
4. Run the stages yourself with [QUICKSTART.md](QUICKSTART.md) (10 minutes)