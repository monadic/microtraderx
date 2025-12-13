# MicroTraderX Visual Guide

Stage-by-stage visual progression showing how the system evolves from a simple deployment to a sophisticated multi-region trading platform.

> **ConfigHub Documentation**: For detailed explanations of ConfigHub concepts (spaces, units, workers, push-upgrade, changesets, filters, lateral promotion), see [docs.confighub.com](https://docs.confighub.com). This guide focuses on MicroTraderX-specific examples.

---

## Table of Contents
1. [Stage 1: Hello TraderX](#stage-1-hello-traderx)
2. [Stage 2: Three Environments](#stage-2-three-environments)
3. [Stage 3: Three Regions](#stage-3-three-regions)
4. [Stage 4: Push-Upgrade](#stage-4-push-upgrade)
5. [Stage 5: Find and Fix](#stage-5-find-and-fix)
6. [Stage 6: Atomic Updates](#stage-6-atomic-updates)
7. [Stage 7: Emergency Bypass](#stage-7-emergency-bypass)

---

## Stage 1: Hello TraderX

**Concept**: Spaces contain units. Workers deploy them.

### Commands
```bash
./setup-structure 1
./deploy 1
```

### Visual Structure

```
┌─────────────────────────────────────────────────────────────┐
│                        ConfigHub                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ traderx/                                             │    │
│  │                                                       │    │
│  │   ┌───────────────────────────────────────────┐     │    │
│  │   │ reference-data                             │     │    │
│  │   │ ────────────────────────────────────────── │     │    │
│  │   │ apiVersion: apps/v1                        │     │    │
│  │   │ kind: Deployment                           │     │    │
│  │   │ metadata:                                  │     │    │
│  │   │   name: reference-data                     │     │    │
│  │   │ spec:                                      │     │    │
│  │   │   replicas: 1                              │     │    │
│  │   │   template:                                │     │    │
│  │   │     containers:                            │     │    │
│  │   │     - name: reference-data                 │     │    │
│  │   │       image: traderx/reference-data:1.0    │     │    │
│  │   │       ports:                               │     │    │
│  │   │       - containerPort: 8080                │     │    │
│  │   └───────────────────────────────────────────┘     │    │
│  │                                                       │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                             │
                             │ Worker deploys
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                       Kubernetes                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Namespace: traderx                                          │
│                                                               │
│  ┌─────────────────────────────────────────────┐            │
│  │ Deployment: reference-data                   │            │
│  │                                               │            │
│  │   ┌─────────────────────────────────┐       │            │
│  │   │ Pod: reference-data-abc123      │       │            │
│  │   │                                  │       │            │
│  │   │ Container: reference-data:1.0   │       │            │
│  │   │ Status: Running ✓               │       │            │
│  │   │ Port: 8080                      │       │            │
│  │   └─────────────────────────────────┘       │            │
│  │                                               │            │
│  └─────────────────────────────────────────────┘            │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### What You Created
- **1 Space**: `traderx`
- **1 Unit**: `reference-data`
- **1 Worker**: Deploys and watches
- **1 Pod**: Running in Kubernetes

### Key Learning
- ConfigHub holds configuration (units in spaces)
- Worker makes it real in Kubernetes
- No direct kubectl needed!

---

## Stage 2: Three Environments

**Concept**: Spaces are environments. Copy promotes config.

### Commands
```bash
./setup-structure 2
./deploy 2
```

### Visual Structure

```
┌──────────────────────────────────────────────────────────────────────┐
│                            ConfigHub                                  │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐       │
│  │ traderx-dev  │      │traderx-staging│     │traderx-prod   │       │
│  ├──────────────┤      ├──────────────┤      ├──────────────┤       │
│  │              │      │              │      │              │       │
│  │ reference-   │      │ reference-   │      │ reference-   │       │
│  │ data         │      │ data         │      │ data         │       │
│  │ (copied)     │      │ (copied)     │      │ (copied)     │       │
│  │              │      │              │      │              │       │
│  └──────────────┘      └──────────────┘      └──────────────┘       │
│   Config only           Config only           Deployed! ✓           │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
                                                      │
                                                      │ Worker in prod
                                                      ▼
                                         ┌──────────────────────┐
                                         │ Kubernetes           │
                                         │                      │
                                         │ Namespace:           │
                                         │  traderx-prod        │
                                         │                      │
                                         │ Pod: reference-data  │
                                         │ Status: Running ✓   │
                                         └──────────────────────┘
```

### Promotion Flow
```
Developer Flow:
┌─────┐     ┌─────┐     ┌─────┐
│ dev │ ──→ │stage│ ──→ │prod │
└─────┘     └─────┘     └─────┘
 Config      Config      LIVE ✓
  only        only      (deployed)

Commands:
1. Test in dev:     cub unit copy reference-data --from traderx --to traderx-dev
2. Promote to staging: cub unit copy reference-data --from traderx-dev --to traderx-staging
3. Deploy to prod:  cub unit copy reference-data --from traderx-staging --to traderx-prod
                    cub unit apply reference-data --space traderx-prod
```

### What You Created
- **3 Spaces**: `dev`, `staging`, `prod`
- **3 Units**: Same config in each space
- **1 Deployment**: Only prod is actually deployed
- **Insight**: ConfigHub separates config (all envs) from deployment (just prod)

### Key Learning
- Environments are spaces
- Config can exist without deployment
- Copy to promote between environments
- Deploy only when ready

---

## Stage 3: Three Regions

**Concept**: Regional scale customization based on business logic.

### Commands
```bash
./setup-structure 3
./deploy 3
```

### Visual Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ConfigHub                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐              │
│  │traderx-prod-us│    │traderx-prod-eu│    │traderx-prod-  │              │
│  │               │    │               │    │     asia      │              │
│  ├───────────────┤    ├───────────────┤    ├───────────────┤              │
│  │               │    │               │    │               │              │
│  │ reference-    │    │ reference-    │    │ reference-    │              │
│  │ data          │    │ data          │    │ data          │              │
│  │ replicas: 1   │    │ replicas: 1   │    │ replicas: 1   │              │
│  │               │    │               │    │               │              │
│  │ trade-service │    │ trade-service │    │ trade-service │              │
│  │ replicas: 3   │    │ replicas: 5   │    │ replicas: 2   │              │
│  │               │    │               │    │               │              │
│  │ NYSE hours    │    │ Peak trading! │    │ Overnight vol │              │
│  │               │    │               │    │               │              │
│  └───────────────┘    └───────────────┘    └───────────────┘              │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
        │                       │                       │
        │ Worker-US             │ Worker-EU             │ Worker-Asia
        ▼                       ▼                       ▼
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│ US Cluster  │         │ EU Cluster  │         │Asia Cluster │
│ us-east-1   │         │ eu-west-1   │         │ap-northeast │
├─────────────┤         ├─────────────┤         ├─────────────┤
│             │         │             │         │             │
│ Pods:       │         │ Pods:       │         │ Pods:       │
│ ┌─┬─┬─┐    │         │ ┌─┬─┬─┬─┬─┐│         │ ┌─┬─┐       │
│ │1│2│3│    │         │ │1│2│3│4│5││         │ │1│2│       │
│ └─┴─┴─┘    │         │ └─┴─┴─┴─┴─┘│         │ └─┴─┘       │
│ replicas:3 │         │ replicas:5  │         │ replicas:2  │
│            │         │             │         │             │
└─────────────┘         └─────────────┘         └─────────────┘
```

### Regional Scaling Rationale

```
Trading Volume by Region:
═════════════════════════

    5 │                    ██
      │                    ██
    4 │                    ██
      │                    ██
    3 │         ██         ██
      │         ██         ██
    2 │         ██         ██         ██
      │         ██         ██         ██
    1 │  ██     ██         ██         ██
      │  ██     ██         ██         ██
    0 └──────────────────────────────────
        US      EU        US+EU      Asia
      Normal   Peak      Combined  Overnight

Replicas:  3       5                    2

Business Logic:
• US: NYSE 9:30am-4pm ET = normal volume = 3 replicas
• EU: London + Frankfurt combined = PEAK volume = 5 replicas
• Asia: Tokyo overnight/after-hours = low volume = 2 replicas
```

### What You Created
- **3 Regional Spaces**: `us`, `eu`, `asia`
- **6 Units**: 2 services × 3 regions
- **3 Workers**: One per region
- **10 Pods Total**: 3+5+2 for trade-service
- **Business Logic**: Replicas match actual trading volume

### Key Learning
- Same config, different scale per region
- ConfigHub preserves regional customizations
- Deployments reflect business requirements
- Cost optimization: Pay only for needed capacity

---

## Stage 4: Push-Upgrade

**Concept**: Update base → flows everywhere, keeps regional scale.

### Commands
```bash
./setup-structure 4
./deploy 4
```

### Visual Structure - Before and After

#### BEFORE Push-Upgrade

```
┌─────────────────────────────────────────────────────────────────┐
│                         ConfigHub                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────┐               │
│  │ traderx-base/trade-service                   │               │
│  │ ───────────────────────────────────────────  │               │
│  │ algorithm: "standard"                        │               │
│  │ image: "trade-service:v1"                    │               │
│  │ timeout: 30s                                 │               │
│  └──────────────────────────────────────────────┘               │
│                       │                                          │
│                       │ upstream-unit links                      │
│                       │                                          │
│      ┌────────────────┼────────────────┐                        │
│      │                │                │                        │
│      ▼                ▼                ▼                        │
│  ┌────────┐      ┌────────┐      ┌────────┐                   │
│  │prod-us │      │prod-eu │      │prod-   │                   │
│  │        │      │        │      │asia    │                   │
│  │v1 ✓    │      │v1 ✓    │      │v1 ✓    │                   │
│  │algo:std│      │algo:std│      │algo:std│                   │
│  │r: 3 ⚡ │      │r: 5 ⚡ │      │r: 2 ⚡ │                   │
│  └────────┘      └────────┘      └────────┘                   │
│  inherited       inherited       inherited                      │
│  + override      + override      + override                     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

#### Update Base

```bash
# Update base unit via stdin (correct pattern)
echo '{"algorithm":"quantum","image":"v2","timeout":"60s"}' | \
  cub unit update trade-service --space traderx-base --patch --from-stdin
```

```
┌─────────────────────────────────────────────────────────────────┐
│  ┌──────────────────────────────────────────────┐               │
│  │ traderx-base/trade-service                   │               │
│  │ ───────────────────────────────────────────  │               │
│  │ algorithm: "QUANTUM" ⚡ CHANGED              │               │
│  │ image: "trade-service:V2" ⚡ CHANGED         │               │
│  │ timeout: 60s ⚡ CHANGED                      │               │
│  └──────────────────────────────────────────────┘               │
│                       │                                          │
│                       │ (not yet propagated)                     │
│                       │                                          │
│      ┌────────────────┼────────────────┐                        │
│      │                │                │                        │
│      ▼                ▼                ▼                        │
│  ┌────────┐      ┌────────┐      ┌────────┐                   │
│  │prod-us │      │prod-eu │      │prod-   │                   │
│  │        │      │        │      │asia    │                   │
│  │v1 ✗    │      │v1 ✗    │      │v1 ✗    │  ← Still old!     │
│  │algo:std│      │algo:std│      │algo:std│                   │
│  │r: 3    │      │r: 5    │      │r: 2    │                   │
│  └────────┘      └────────┘      └────────┘                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

#### Push-Upgrade

```bash
cub unit update --upgrade --patch --space 'traderx-prod-*'
```

```
┌─────────────────────────────────────────────────────────────────┐
│  ┌──────────────────────────────────────────────┐               │
│  │ traderx-base/trade-service                   │               │
│  │ ───────────────────────────────────────────  │               │
│  │ algorithm: "quantum"                         │               │
│  │ image: "trade-service:v2"                    │               │
│  │ timeout: 60s                                 │               │
│  └──────────────────────────────────────────────┘               │
│                       │                                          │
│                       │ PUSH-UPGRADE! ⚡⚡⚡                    │
│                       │                                          │
│      ┌────────────────┼────────────────┐                        │
│      │                │                │                        │
│      ▼                ▼                ▼                        │
│  ┌────────┐      ┌────────┐      ┌────────┐                   │
│  │prod-us │      │prod-eu │      │prod-   │                   │
│  │        │      │        │      │asia    │                   │
│  │V2 ✓    │      │V2 ✓    │      │V2 ✓    │  ← Updated!       │
│  │algo:QM │      │algo:QM │      │algo:QM │                   │
│  │r: 3 ✓  │      │r: 5 ✓  │      │r: 2 ✓  │  ← Preserved!     │
│  └────────┘      └────────┘      └────────┘                   │
│  new algo        new algo        new algo                       │
│  + kept scale    + kept scale    + kept scale                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### The Magic

```
What Changed:
✓ Algorithm: standard → quantum (all regions)
✓ Image: v1 → v2 (all regions)
✓ Timeout: 30s → 60s (all regions)

What Was Preserved:
✓ US replicas: 3 (unchanged)
✓ EU replicas: 5 (unchanged)
✓ Asia replicas: 2 (unchanged)

Traditional Tools Would Need:
1. Edit us/deployment.yaml manually
2. Edit eu/deployment.yaml manually
3. Edit asia/deployment.yaml manually
4. kubectl apply × 3
5. Hope you didn't make mistakes!

ConfigHub Needs:
1. Update base
2. Push-upgrade
3. Done! ✓
```

### What You Created
- **1 Base Space**: Single source of truth
- **Upstream Links**: Regions inherit from base
- **Push-Upgrade**: One command updates all
- **Preserved Overrides**: Regional scale maintained

### Key Learning
- Inheritance via `upstream-unit`
- Push-upgrade propagates changes
- Local overrides preserved automatically
- One command updates entire global platform

---

## Stage 5: Find and Fix

**Concept**: SQL-like WHERE clauses find and fix problems globally.

### Commands
```bash
./setup-structure 5
./deploy 5
```

### Visual Structure

```
┌──────────────────────────────────────────────────────────────────────┐
│                         ConfigHub Query Engine                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Query: WHERE Space.Slug LIKE '%prod-eu%' AND spec.replicas > 2      │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Search across ALL spaces and units                              │  │
│  └────────────────────────────────────────────────────────────────┘  │
│           │                                                            │
│           ▼ Scans                                                      │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                │
│  │ prod-us     │   │ prod-eu     │   │ prod-asia   │                │
│  │ replicas: 3 │   │ replicas: 5 │   │ replicas: 2 │                │
│  │      ✗      │   │      ✓      │   │      ✗      │                │
│  └─────────────┘   └─────────────┘   └─────────────┘                │
│   doesn't match      MATCHES!          doesn't match                  │
│                                                                        │
│  Result:                                                               │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ traderx-prod-eu/trade-service                                   │  │
│  │ • replicas: 5                                                   │  │
│  │ • image: trade-service:v2                                       │  │
│  │ • status: Running                                               │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

### Use Cases

#### Use Case 1: Scale Down EU After Market Close
```bash
# Markets closed at 4:30pm GMT, reduce replicas

cub run set-replicas --replicas 2 \
  --space traderx-prod-eu \
  --where "spec.replicas > 2"
```

```
Before (4:30pm GMT):
┌─────────────┐
│ prod-eu     │
│ replicas: 5 │  ← Peak trading (markets open)
│             │
│ ┌─┬─┬─┬─┬─┐│
│ │1│2│3│4│5││
│ └─┴─┴─┴─┴─┘│
└─────────────┘

After:
┌─────────────┐
│ prod-eu     │
│ replicas: 2 │  ← Scaled down (markets closed)
│             │
│ ┌─┬─┐       │
│ │1│2│       │
│ └─┴─┘       │
└─────────────┘

Cost savings: 60% reduction (5 → 2 pods)
```

#### Use Case 2: Find All Old Versions
```bash
cub unit list --space "*" \
  --where "Data CONTAINS 'image: trade-service:v1'"
```

```
Scanning all spaces...

Results:
┌────────────────────────────────────────────────┐
│ Units still running old version:               │
│                                                 │
│ ✗ traderx-dev/trade-service                    │
│   image: trade-service:v1 (outdated!)          │
│                                                 │
│ ✓ traderx-prod-us/trade-service                │
│   image: trade-service:v2 (up to date)         │
│                                                 │
│ ✓ traderx-prod-eu/trade-service                │
│   image: trade-service:v2 (up to date)         │
│                                                 │
│ ✓ traderx-prod-asia/trade-service              │
│   image: trade-service:v2 (up to date)         │
└────────────────────────────────────────────────┘

Action: Update dev to v2
```

#### Use Case 3: Find High-Memory Services
```bash
cub unit list --space "*" \
  --where "Data CONTAINS 'memory:' AND Data CONTAINS '1Gi'"
```

### What You Created
- **Query Engine**: SQL-like WHERE clauses
- **Global Search**: Across all spaces and units
- **Bulk Actions**: Fix problems at scale
- **Cost Optimization**: Find and fix inefficiencies

### Key Learning
- WHERE clauses work across entire platform
- Find anomalies, old versions, misconfigurations
- Fix at scale with one command
- Better than manual searching through YAML files

---

## Stage 6: Atomic Updates

**Concept**: Changesets ensure related services update together.

### Commands
```bash
./setup-structure 6
./deploy 6
```

### Visual Structure

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Changeset: market-data-v2                     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Problem: New market data format requires BOTH services to update     │
│  Solution: Changeset groups changes, applies atomically               │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Changeset Contents:                                             │  │
│  │                                                                  │  │
│  │ 1. reference-data: v1 → v2 (new data format)                   │  │
│  │    image: traderx/reference-data:v1 → v2                        │  │
│  │                                                                  │  │
│  │ 2. trade-service: v1 → v2 (reads new format)                   │  │
│  │    image: traderx/trade-service:v1 → v2                         │  │
│  │                                                                  │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

### Atomic Application Flow

```
WITHOUT Changeset (DANGEROUS!):
═══════════════════════════════

Step 1: Update reference-data
┌──────────────┐     ┌──────────────┐
│ ref-data: v2 │     │ trade-svc:v1 │  ← Incompatible!
│ (new format) │ ──▶ │ (old format) │
└──────────────┘     └──────────────┘
     ✓ Applied            ✗ BREAKS!

Result: BROKEN TRADES! ✗
  • reference-data sends new format
  • trade-service can't parse it
  • Trades fail!

Step 2: Update trade-service separately
┌──────────────┐     ┌──────────────┐
│ ref-data: v2 │     │ trade-svc:v2 │
│ (new format) │ ──▶ │ (new format) │
└──────────────┘     └──────────────┘
     ✓ Works           ✓ Fixed

Result: Services out of sync, trades broken!


WITH Changeset (SAFE!):
═══════════════════════

cub changeset create market-data-v2

# Stage updates via stdin
echo '{"image":"v2"}' | cub unit update reference-data --space traderx-prod-us \
  --patch --from-stdin

echo '{"image":"v2"}' | cub unit update trade-service --space traderx-prod-us \
  --patch --from-stdin

cub changeset apply market-data-v2

┌─────────────────────────────────────────────┐
│ Changeset Application (Atomic)              │
│                                              │
│  Preparing...                                │
│  ✓ Validate reference-data update           │
│  ✓ Validate trade-service update            │
│                                              │
│  Applying both together...                  │
│  ┌──────────────┐     ┌──────────────┐     │
│  │ ref-data: v2 │     │ trade-svc:v2 │     │
│  │ (new format) │ ──▶ │ (new format) │     │
│  └──────────────┘     └──────────────┘     │
│  ✓ Applied            ✓ Applied             │
│                                              │
│  Result: BOTH updated at once! ✓✓✓         │
└─────────────────────────────────────────────┘

Result: ZERO downtime! ✓
  • Both services update together
  • No incompatible state
  • No broken trades!
```

### Timeline Comparison

```
Traditional Approach:
═══════════════════

T+0s:   Update reference-data (kubectl apply)
        ✓ Deployed
T+1s:   ✗ Trades start failing (incompatible formats)
T+30s:  ✗ Still failing...
T+60s:  ✗ Still failing...
T+300s: Update trade-service (kubectl apply)
        ✓ Deployed
T+301s: ✓ Trades working again

Downtime: Services out of sync, trades broken!


ConfigHub Changeset:
═══════════════════

T+0s:   cub changeset create market-data-v2
T+1s:   cub unit update reference-data (staged)
T+2s:   cub unit update trade-service (staged)
T+3s:   cub changeset apply market-data-v2
T+4s:   ✓ Both services updated simultaneously
T+5s:   ✓ Trades working perfectly

Downtime: ZERO! ✓✓✓
```

### What You Created
- **Changeset**: Group of related changes
- **Atomic Application**: All or nothing
- **Zero Downtime**: No incompatible states
- **Safety**: Related services stay in sync

### Key Learning
- Changesets prevent partial deployments
- Atomic updates ensure consistency
- Related services must update together
- No broken intermediate states

---

## Stage 7: Emergency Bypass

**Concept**: Lateral promotion for emergency fixes.

### Commands
```bash
./setup-structure 7
./deploy 7
```

### Visual Structure - Emergency Scenario

```
┌──────────────────────────────────────────────────────────────────────┐
│                      EMERGENCY: Trading Bug in EU                     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Time: 6:00am GMT (EU markets opening)                                │
│  Problem: Trades executing at WRONG PRICE! ✗                         │
│  Impact: Losing money every second!                                   │
│  Constraint: Asia markets open in 2 hours                             │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

#### Normal Flow (TOO SLOW!)
```
Normal Promotion Flow:
═══════════════════════

dev → staging → us → eu → asia
 ↓       ↓      ↓     ↓     ↓
30m     30m    30m   30m   30m

Total time: 2.5 hours ✗

Asia markets open in 2 hours!
CAN'T WAIT! Need emergency bypass!
```

#### Emergency Lateral Promotion

```
Step 1: Fix Directly in EU (6:00am GMT)
════════════════════════════════════════

cub run set-env-var --env-var CIRCUIT_BREAKER=true \
  --unit trade-service --space traderx-prod-eu

┌─────────────────┐
│ prod-eu         │
│ ─────────────── │
│ CIRCUIT_BREAKER │
│ = true          │
│                 │
│ STATUS: FIXED ✓ │
└─────────────────┘

EU markets safe! Time: 6:05am GMT


Step 2: Lateral Promotion EU → Asia (6:10am GMT)
═════════════════════════════════════════════════

# Skip normal flow, go directly EU → Asia

cub unit update trade-service --space traderx-prod-asia \
  --merge-unit traderx-prod-eu/trade-service

Normal flow:    dev → staging → us → eu → asia
Emergency flow:                       eu → asia  ✓

┌─────────────────┐          ┌─────────────────┐
│ prod-eu         │          │ prod-asia       │
│ ─────────────── │   ═══▶   │ ─────────────── │
│ CIRCUIT_BREAKER │          │ CIRCUIT_BREAKER │
│ = true          │          │ = true          │
│                 │          │                 │
│ FIXED 6:05am ✓  │          │ FIXED 6:10am ✓  │
└─────────────────┘          └─────────────────┘

Asia markets safe BEFORE they open! Time: 6:10am GMT


Step 3: Backfill US (6:00pm GMT - US Markets Closed)
═════════════════════════════════════════════════════

cub unit update trade-service --space traderx-prod-us \
  --merge-unit traderx-prod-eu/trade-service

┌─────────────────┐          ┌─────────────────┐
│ prod-eu         │          │ prod-us         │
│ ─────────────── │   ═══▶   │ ─────────────── │
│ CIRCUIT_BREAKER │          │ CIRCUIT_BREAKER │
│ = true          │          │ = true          │
│                 │          │                 │
│ FIXED 6:05am ✓  │          │ BACKFILLED 6pm ✓│
└─────────────────┘          └─────────────────┘

US updated during closed hours (safe!) Time: 6:00pm GMT


Step 4: Update Base (Next Day)
═══════════════════════════════

cub unit update trade-service --space traderx-base \
  --merge-unit traderx-prod-eu/trade-service

┌─────────────────┐
│ base            │
│ ─────────────── │
│ CIRCUIT_BREAKER │
│ = true          │
│                 │
│ ROOT CAUSE FIX ✓│
└─────────────────┘

All future deployments include fix! ✓
```

### Complete Timeline

```
Emergency Timeline:
═══════════════════

6:00am GMT  ✗ EU bug discovered (trades at wrong price)
            │
            ├─ EU markets OPEN, losing money!
            │
6:05am GMT  ✓ Fix applied directly to EU
            │  cub run set-env-var CIRCUIT_BREAKER=true
            │
            ├─ EU markets now SAFE ✓
            │
6:10am GMT  ✓ Lateral promotion EU → Asia
            │  cub unit update --merge-unit
            │
            ├─ Asia markets will be SAFE when they open ✓
            │
8:00am JST  ✓ Asia markets open (already protected!)
            │
6:00pm GMT  ✓ Backfill US (markets closed)
            │  cub unit update --merge-unit
            │
Next Day    ✓ Update base (root cause fix)
            │  cub unit update base --merge-unit
            │
            └─ All regions safe, base fixed ✓✓✓

Emergency response: Immediate lateral promotion
Total regions protected: 3/3
Trading losses prevented: Millions! ✓
```

### Flow Diagram

```
Normal Flow (Can't Use!):
═════════════════════════
┌─────┐    ┌────────┐    ┌──────┐    ┌──────┐    ┌──────┐
│ dev │───▶│staging │───▶│  us  │───▶│  eu  │───▶│ asia │
└─────┘    └────────┘    └──────┘    └──────┘    └──────┘
  30m         30m          30m         30m         30m
                                                     ▲
                                                     │
                                              Opens in 2h!
                                              TOO SLOW! ✗


Emergency Flow (Lateral Promotion):
═══════════════════════════════════
┌─────┐    ┌────────┐    ┌──────┐
│ dev │    │staging │    │  us  │  (Backfill later)
└─────┘    └────────┘    └──────┘
                             ▲
                             │
                          6:00pm GMT
                      (markets closed)
                             │
┌──────┐    ┌──────┐        │
│  eu  │───▶│ asia │────────┘
└──────┘    └──────┘
  6:05am     6:10am
 EMERGENCY!   SAFE!
    ✓          ✓

Asia protected via lateral promotion
```

### What You Created
- **Complete System**: Base + dev + staging + 3 prod regions
- **Normal Flow**: Structured promotion path
- **Emergency Flow**: Lateral promotion capability
- **Backfill**: Update skipped regions later
- **Root Cause Fix**: Update base when safe

### Key Learning
- Normal flow for planned changes
- Lateral promotion for emergencies
- Business-aware: Respects market hours
- Audit trail: All changes tracked
- Flexibility: Can bypass normal flow when needed

---

## Stage Progression Summary

```
Stage 1: Hello TraderX
──────────────────────
Spaces + Units + Worker = Deployment
┌───────┐
│traderx│
└───────┘


Stage 2: Three Environments
────────────────────────────
Spaces are environments
┌─────┐ ┌────────┐ ┌──────┐
│ dev │ │staging │ │ prod │
└─────┘ └────────┘ └──────┘


Stage 3: Three Regions
──────────────────────
Regional customization
┌──────┐ ┌──────┐ ┌──────┐
│ us:3 │ │ eu:5 │ │asia:2│
└──────┘ └──────┘ └──────┘


Stage 4: Push-Upgrade
─────────────────────
Inheritance + propagation
    ┌──────┐
    │ base │
    └───┬──┘
  ┌─────┼─────┐
  ▼     ▼     ▼
┌───┐ ┌───┐ ┌───┐
│us │ │eu │ │asia│
└───┘ └───┘ └───┘


Stage 5: Find and Fix
─────────────────────
SQL-like WHERE clauses
┌──────────────────┐
│ WHERE replicas>2 │
└─────────┬────────┘
          ▼
     ┌────────┐
     │ eu:5 ✓ │
     └────────┘


Stage 6: Atomic Updates
───────────────────────
Changesets for consistency
┌────────────────┐
│ Changeset:     │
│ • ref-data: v2 │
│ • trade-svc:v2 │
└────────────────┘
   Apply both! ✓


Stage 7: Emergency Bypass
─────────────────────────
Lateral promotion
     eu ──▶ asia
      │
      └──▶ us (later)
```

## Summary

This visual guide shows the evolution of MicroTraderX from a simple single-service deployment to a sophisticated multi-region trading platform with:

- **Regional scaling** based on business logic
- **Inheritance** for consistent base configuration
- **Push-upgrade** for global updates
- **Find and fix** for bulk operations
- **Atomic updates** for consistency
- **Emergency bypass** for critical situations

Each stage builds on the previous, demonstrating ConfigHub's power for managing complex, multi-region deployments with business-aware configuration management.
