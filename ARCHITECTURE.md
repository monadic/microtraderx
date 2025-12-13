# MicroTraderX Architecture

Visual diagrams showing the complete system architecture, inheritance patterns, and deployment flows.

> **ConfigHub Documentation**: For detailed explanations of ConfigHub concepts (spaces, units, workers, upstream/downstream inheritance, push-upgrade, lateral promotion), see [docs.confighub.com](https://docs.confighub.com). This document focuses on MicroTraderX-specific architecture.

---

## Table of Contents
1. [Complete System Architecture](#complete-system-architecture)
2. [3-Region Architecture](#3-region-architecture)
3. [Inheritance Flow](#inheritance-flow)
4. [Push-Upgrade Pattern](#push-upgrade-pattern)
5. [Emergency Lateral Promotion](#emergency-lateral-promotion)
6. [ConfigHub to Kubernetes Flow](#confighub-to-kubernetes-flow)

---

## Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          CONFIGHUB STRUCTURE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      traderx-base                                  │  │
│  │  ┌──────────────────────┐  ┌──────────────────────┐              │  │
│  │  │ reference-data-base  │  │ trade-service-base   │              │  │
│  │  │ (Market data config) │  │ (Trading engine)     │              │  │
│  │  └──────────────────────┘  └──────────────────────┘              │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│           │                                    │                         │
│           │ push-upgrade                       │ push-upgrade            │
│           ├────────────────┬───────────────────┼──────────────┐         │
│           │                │                   │              │         │
│           ▼                ▼                   ▼              ▼         │
│  ┌────────────────┐ ┌────────────────┐ ┌──────────────┐ ┌─────────┐   │
│  │ traderx-dev    │ │ traderx-staging│ │ prod-us      │ │ prod-eu │...│
│  │ ┌────────────┐ │ │ ┌────────────┐ │ │ ┌──────────┐ │ │         │   │
│  │ │ ref-data ─┼ │ │ │ ref-data ─┼ │ │ │ ref-data │ │ │         │   │
│  │ │ (→base)    │ │ │ │ (→base)    │ │ │ │ (→base)  │ │ │         │   │
│  │ └────────────┘ │ │ └────────────┘ │ │ └──────────┘ │ │         │   │
│  │ ┌────────────┐ │ │ ┌────────────┐ │ │ ┌──────────┐ │ │         │   │
│  │ │ trade-svc ─┼ │ │ │ trade-svc ─┼ │ │ │trade-svc │ │ │         │   │
│  │ │ (→base)    │ │ │ │ (→base)    │ │ │ │ (→base)  │ │ │         │   │
│  │ │ replicas:1 │ │ │ │ replicas:2 │ │ │ │replicas:3│ │ │         │   │
│  │ └────────────┘ │ │ └────────────┘ │ │ └──────────┘ │ │         │   │
│  └────────────────┘ └────────────────┘ └──────────────┘ └─────────┘   │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

                                    ⬇ ConfigHub Workers

┌─────────────────────────────────────────────────────────────────────────┐
│                         KUBERNETES CLUSTERS                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌────────────────┐ ┌────────────────┐ ┌──────────────┐ ┌─────────────┐│
│  │  dev cluster   │ │ staging cluster│ │  us cluster  │ │  eu cluster ││
│  │  namespace:    │ │  namespace:    │ │  namespace:  │ │  namespace: ││
│  │  traderx-dev   │ │traderx-staging │ │traderx-prod- │ │traderx-prod-││
│  │                │ │                │ │      us      │ │     eu      ││
│  │  replicas: 1   │ │  replicas: 2   │ │  replicas: 3 │ │ replicas: 5 ││
│  │                │ │                │ │  (NYSE vol)  │ │ (Peak vol)  ││
│  └────────────────┘ └────────────────┘ └──────────────┘ └─────────────┘│
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key Concepts**: See [docs.confighub.com](https://docs.confighub.com) for base spaces, inheritance, and push-upgrade. MicroTraderX demonstrates regional customization where each region has unique replica counts (US:3, EU:5, Asia:2) preserved during upgrades.

---

## 3-Region Architecture

The trading platform scales based on market activity in each region:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        GLOBAL TRADING PLATFORM                            │
└──────────────────────────────────────────────────────────────────────────┘

    US Region (NYSE)          EU Region (London)      Asia Region (Tokyo)
    ════════════════          ══════════════════      ═══════════════════

┌─────────────────┐       ┌──────────────────┐      ┌─────────────────┐
│  traderx-prod-us│       │ traderx-prod-eu  │      │traderx-prod-asia│
├─────────────────┤       ├──────────────────┤      ├─────────────────┤
│                 │       │                  │      │                 │
│ reference-data  │       │ reference-data   │      │ reference-data  │
│   replicas: 1   │       │   replicas: 1    │      │   replicas: 1   │
│   ┌───────┐     │       │   ┌───────┐      │      │   ┌───────┐     │
│   │ Pod 1 │     │       │   │ Pod 1 │      │      │   │ Pod 1 │     │
│   └───────┘     │       │   └───────┘      │      │   └───────┘     │
│                 │       │                  │      │                 │
│ trade-service   │       │ trade-service    │      │ trade-service   │
│   replicas: 3   │       │   replicas: 5    │      │   replicas: 2   │
│   ┌───┬───┬───┐ │       │ ┌─┬─┬─┬─┬─┐     │      │   ┌───┬───┐     │
│   │P1 │P2 │P3 │ │       │ │1│2│3│4│5│     │      │   │P1 │P2 │     │
│   └───┴───┴───┘ │       │ └─┴─┴─┴─┴─┘     │      │   └───┴───┘     │
│                 │       │                  │      │                 │
│ Trading Hours:  │       │ Trading Hours:   │      │ Trading Hours:  │
│ 9:30am - 4pm ET │       │ 8am - 4:30pm GMT │      │ 9am - 3pm JST   │
│ Normal volume   │       │ PEAK volume      │      │ Overnight vol   │
│                 │       │ (LON + FRA)      │      │                 │
└─────────────────┘       └──────────────────┘      └─────────────────┘

     US-EAST-1                 EU-WEST-1              AP-NORTHEAST-1
    (Virginia)                 (Ireland)                (Tokyo)
```

**Regional Scaling Logic**:
- **US**: 3 replicas - NYSE normal trading hours
- **EU**: 5 replicas - Combined London + Frankfurt exchanges (highest volume)
- **Asia**: 2 replicas - Tokyo overnight/after-hours trading (lowest volume)

**Why This Matters**:
- Cost optimization: Pay only for needed capacity
- Performance: Right-sized for actual trading volume
- Business logic: Reflects real-world market activity patterns

---

## Inheritance Flow

This diagram shows how configuration inherits from base to regions:

```
                              traderx-base
                                   │
                     ┌─────────────┴─────────────┐
                     │                           │
                  reference-data-base      trade-service-base
                     │                           │
           ┌─────────┼─────────┐       ┌─────────┼─────────┐
           │         │         │       │         │         │
           ▼         ▼         ▼       ▼         ▼         ▼
        us-ref    eu-ref   asia-ref  us-trade eu-trade asia-trade
     (inherits) (inherits)(inherits)(inherits)(inherits)(inherits)


INHERITANCE PROPERTIES:

┌──────────────────────────────────────────────────────────────────┐
│ Base Unit                                                         │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ image: trade-service:v1                                      │ │
│ │ algorithm: standard                                          │ │
│ │ timeout: 30s                                                 │ │
│ │ replicas: 1  ← Default (can be overridden)                  │ │
│ └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ upstream-unit link
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
   ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
   │ US Region      │ │ EU Region      │ │ Asia Region    │
   ├────────────────┤ ├────────────────┤ ├────────────────┤
   │ image: v1 ✓    │ │ image: v1 ✓    │ │ image: v1 ✓    │
   │ algorithm: ✓   │ │ algorithm: ✓   │ │ algorithm: ✓   │
   │ timeout: 30s ✓ │ │ timeout: 30s ✓ │ │ timeout: 30s ✓ │
   │ replicas: 3 ⚡ │ │ replicas: 5 ⚡ │ │ replicas: 2 ⚡ │
   └────────────────┘ └────────────────┘ └────────────────┘
        Override         Override         Override
```

**Legend**:
- ✓ = Inherited from base
- ⚡ = Local override (preserved during push-upgrade)

**How It Works**:
1. Regional units have `upstream-unit` pointing to base
2. Most properties inherit automatically
3. Local overrides (like replicas) are preserved
4. Updates to base flow to regions via push-upgrade

---

## Push-Upgrade Pattern

The killer feature that beats traditional config management:

```
BEFORE PUSH-UPGRADE:
═══════════════════

traderx-base/trade-service
┌──────────────────────────┐
│ algorithm: standard      │
│ image: v1                │
│ timeout: 30s             │
└──────────────────────────┘
            │
            │ upstream-unit
            │
    ┌───────┼───────┐
    │       │       │
    ▼       ▼       ▼
  ┌────┐ ┌────┐ ┌────┐
  │ US │ │ EU │ │Asia│
  │ v1 │ │ v1 │ │ v1 │
  │ r:3│ │ r:5│ │ r:2│
  └────┘ └────┘ └────┘


STEP 1: Update Base
════════════════════

# Update base unit via stdin (correct pattern)
echo '{"algorithm":"quantum","image":"v2","timeout":"60s"}' | \
  cub unit update trade-service --space traderx-base --patch --from-stdin

traderx-base/trade-service
┌──────────────────────────┐
│ algorithm: QUANTUM ⚡    │  ← Changed
│ image: V2 ⚡             │  ← Changed
│ timeout: 60s ⚡          │  ← Changed
└──────────────────────────┘
            │
            │ (not yet propagated)
            │
    ┌───────┼───────┐
    │       │       │
    ▼       ▼       ▼
  ┌────┐ ┌────┐ ┌────┐
  │ US │ │ EU │ │Asia│
  │ v1 │ │ v1 │ │ v1 │  ← Still old!
  │ r:3│ │ r:5│ │ r:2│
  └────┘ └────┘ └────┘


STEP 2: Push-Upgrade
═══════════════════════

cub unit update --upgrade --patch --space 'traderx-prod-*'

traderx-base/trade-service
┌──────────────────────────┐
│ algorithm: quantum       │
│ image: v2                │
│ timeout: 60s             │
└──────────────────────────┘
            │
            │ push-upgrade ⚡⚡⚡
            │
    ┌───────┼───────┐
    │       │       │
    ▼       ▼       ▼
  ┌────┐ ┌────┐ ┌────┐
  │ US │ │ EU │ │Asia│
  │ V2 │ │ V2 │ │ V2 │  ← Algorithm updated! ✓
  │ r:3│ │ r:5│ │ r:2│  ← Replicas preserved! ✓
  └────┘ └────┘ └────┘


AFTER PUSH-UPGRADE:
═══════════════════

All regions now have:
✓ New algorithm (quantum)
✓ New image version (v2)
✓ New timeout (60s)
✓ ORIGINAL replica counts (3, 5, 2)

US Region:               EU Region:              Asia Region:
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ algorithm: ✓    │     │ algorithm: ✓    │     │ algorithm: ✓    │
│ image: v2 ✓     │     │ image: v2 ✓     │     │ image: v2 ✓     │
│ timeout: 60s ✓  │     │ timeout: 60s ✓  │     │ timeout: 60s ✓  │
│ replicas: 3 ⚡  │     │ replicas: 5 ⚡  │     │ replicas: 2 ⚡  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Result**: One command updates all three regions while preserving regional replica counts. See [push-upgrade documentation](https://docs.confighub.com) for details.

---

## Emergency Lateral Promotion

When you can't follow the normal dev → staging → prod flow:

```
NORMAL PROMOTION FLOW:
═══════════════════════

traderx-base
     │
     ├─→ traderx-dev
     │        │
     │        ↓ test & promote
     ├─→ traderx-staging
     │        │
     │        ↓ test & promote
     ├─→ traderx-prod-us
     │        │
     │        ↓ test & promote
     ├─→ traderx-prod-eu
     │        │
     │        ↓ test & promote
     └─→ traderx-prod-asia

Time: ~2-3 hours for full pipeline


EMERGENCY SCENARIO:
═══════════════════════

Time: 6:00am GMT - EU markets open
Issue: Critical trading bug discovered in EU

┌──────────────────────────────────────────────────────────────┐
│ EU discovers bug: trades executing at wrong price!           │
│ Asia markets open in 2 hours                                 │
│ US markets closed (overnight)                                │
│ CAN'T WAIT for US testing!                                   │
└──────────────────────────────────────────────────────────────┘


LATERAL PROMOTION (Emergency Bypass):
═══════════════════════════════════════

Step 1: Fix directly in EU (6:05am GMT)
─────────────────────────────────────────
cub run set-env-var --env-var CIRCUIT_BREAKER=true \
  --unit trade-service --space traderx-prod-eu

┌────────────────┐
│ traderx-prod-eu│
│ FIXED! ✓       │
│ CIRCUIT_BREAKER│
│ = true         │
└────────────────┘


Step 2: Lateral promotion to Asia (6:10am GMT)
───────────────────────────────────────────────
# Skip US (closed), go directly EU → Asia

cub unit update trade-service --space traderx-prod-asia \
  --merge-unit traderx-prod-eu/trade-service

     traderx-prod-eu  ──────→  traderx-prod-asia
     (FIXED 6:05am)            (FIXED 6:10am)
            │                         │
            │                         │
            ▼                         ▼
    EU markets safe          Asia markets safe
      6:05am GMT               8:00am JST


Step 3: Backfill US when safe (6:00pm GMT)
───────────────────────────────────────────
# US markets closed, safe to update

cub unit update trade-service --space traderx-prod-us \
  --merge-unit traderx-prod-eu/trade-service

     traderx-prod-eu  ──────→  traderx-prod-us
     (FIXED 6:05am)            (BACKFILLED 6pm)


Step 4: Update base for future (next day)
──────────────────────────────────────────
cub unit update trade-service --space traderx-base \
  --merge-unit traderx-prod-eu/trade-service


TIMELINE VISUALIZATION:
═══════════════════════

Time    Event                          Action
─────   ──────────────────────────     ─────────────────────────────
6:00am  EU bug discovered              Emergency!
6:05am  Fix applied to EU              EU now safe ✓
6:10am  EU → Asia (lateral)            Asia now safe ✓
6:00pm  EU → US (backfill)             US updated (markets closed)
Next    US → base (standard flow)      Base updated for future


FLOW DIAGRAM:
═════════════

Normal:     dev → staging → us → eu → asia

Emergency:              ┌──→ asia  (immediate)
                        │
                        eu ──→ us   (backfill when safe)
                        │
                        └──→ base   (fix root cause)
```

**Why This Matters for MicroTraderX**: Lateral promotion lets EU emergency fixes reach Asia before Tokyo markets open (2 hour window), while US backfill happens safely during market close. See [lateral promotion documentation](https://docs.confighub.com) for details.

---

## ConfigHub to Kubernetes Flow

How configurations become running pods:

```
┌───────────────────────────────────────────────────────────────────┐
│                    DEVELOPER WORKFLOW                              │
└───────────────────────────────────────────────────────────────────┘

Step 1: Create Structure (ConfigHub only)
──────────────────────────────────────────

./setup-structure 7

Creates:
┌─────────────────────────────────────────────────┐
│ ConfigHub API                                    │
├─────────────────────────────────────────────────┤
│ Spaces:                                          │
│   - traderx-base                                 │
│   - traderx-dev, traderx-staging                │
│   - traderx-prod-us, -eu, -asia                 │
│                                                   │
│ Units (per space):                               │
│   - reference-data (with upstream-unit)          │
│   - trade-service (with upstream-unit)           │
│                                                   │
│ Relationships:                                   │
│   - base → dev, staging, prod-* (inheritance)    │
│   - Regional overrides (replicas)                │
└─────────────────────────────────────────────────┘

At this point: NO Kubernetes resources exist!
Just pure configuration in ConfigHub.


Step 2: Deploy to Kubernetes
─────────────────────────────

./deploy 7

For each space (e.g., traderx-prod-us):

┌─────────────────────────────────────────────────┐
│ 1. Install Worker                                │
│    cub worker install worker-us                  │
│       --space traderx-prod-us                    │
│       --wait                                     │
│                                                   │
│    Creates:                                      │
│    • Kubernetes Deployment (worker pod)          │
│    • ServiceAccount + RBAC                       │
│    • Watches ConfigHub for changes               │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 2. Apply Units                                   │
│    cub unit apply --space traderx-prod-us        │
│                   --where "*"                    │
│                                                   │
│    Worker reads ConfigHub units and creates:     │
│    • Namespace: traderx-prod-us                  │
│    • Deployment: reference-data                  │
│    • Deployment: trade-service (replicas: 3)     │
│    • Services, ConfigMaps, etc.                  │
└─────────────────────────────────────────────────┘


DETAILED FLOW FOR ONE REGION (US):
═══════════════════════════════════

┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│  ConfigHub   │         │    Worker    │         │  Kubernetes  │
│     API      │         │   (in K8s)   │         │   API Server │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘
       │                        │                        │
       │  1. cub worker install │                        │
       │  ─────────────────────>│                        │
       │                        │ 2. Create worker pod   │
       │                        │ ──────────────────────>│
       │                        │                        │
       │                        │ 3. Worker starts       │
       │                        │<───────────────────────│
       │                        │                        │
       │  4. cub unit apply     │                        │
       │  ─────────────────────>│                        │
       │                        │                        │
       │  5. Fetch units from   │                        │
       │     traderx-prod-us    │                        │
       │<───────────────────────│                        │
       │                        │                        │
       │  6. Return unit configs│                        │
       │  ─────────────────────>│                        │
       │                        │                        │
       │                        │ 7. Create namespace    │
       │                        │ ──────────────────────>│
       │                        │                        │
       │                        │ 8. Create deployments  │
       │                        │    (reference-data,    │
       │                        │     trade-service)     │
       │                        │ ──────────────────────>│
       │                        │                        │
       │                        │ 9. Pods scheduled      │
       │                        │<───────────────────────│
       │                        │                        │
       │ 10. Update live-state  │                        │
       │<───────────────────────│                        │
       │                        │                        │
       │                        │ ∞ Watch for changes    │
       │                        │<──────────────────────>│
       │                        │                        │
```

**Worker Details**: See [worker documentation](https://docs.confighub.com) for installation, RBAC, live-state reporting, and reconciliation. In MicroTraderX, each regional cluster has its own worker managing that space.

---

## Multi-Cluster Deployment

Real-world scenario with separate clusters per region:

```
┌────────────────────────────────────────────────────────────────────┐
│                         CONFIGHUB (Central)                         │
│                        https://confighub.com                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  traderx-base    traderx-dev    traderx-staging                    │
│  traderx-prod-us    traderx-prod-eu    traderx-prod-asia           │
│                                                                      │
└───────┬──────────────────────┬──────────────────────┬──────────────┘
        │                      │                      │
        │ Worker pulls         │ Worker pulls         │ Worker pulls
        │ traderx-prod-us      │ traderx-prod-eu      │ traderx-prod-asia
        │                      │                      │
        ▼                      ▼                      ▼
┌──────────────┐       ┌──────────────┐      ┌──────────────┐
│ US Cluster   │       │ EU Cluster   │      │ Asia Cluster │
│ us-east-1    │       │ eu-west-1    │      │ ap-northeast │
├──────────────┤       ├──────────────┤      ├──────────────┤
│              │       │              │      │              │
│ worker-us    │       │ worker-eu    │      │ worker-asia  │
│   ↓          │       │   ↓          │      │   ↓          │
│ ┌──────────┐ │       │ ┌──────────┐ │      │ ┌──────────┐ │
│ │Namespace │ │       │ │Namespace │ │      │ │Namespace │ │
│ │traderx-  │ │       │ │traderx-  │ │      │ │traderx-  │ │
│ │ prod-us  │ │       │ │ prod-eu  │ │      │ │prod-asia │ │
│ │          │ │       │ │          │ │      │ │          │ │
│ │ Pods: 3  │ │       │ │ Pods: 5  │ │      │ │ Pods: 2  │ │
│ └──────────┘ │       │ └──────────┘ │      │ └──────────┘ │
│              │       │              │      │              │
└──────────────┘       └──────────────┘      └──────────────┘
```

**MicroTraderX Benefit**: Single ConfigHub control plane manages all 3 regional clusters, enabling global updates via push-upgrade while each region operates independently with local workers.

---

## Summary

MicroTraderX demonstrates ConfigHub patterns applied to a multi-region trading platform:

- **Base → Regional inheritance** with US:3, EU:5, Asia:2 replica customization preserved
- **Push-upgrade** propagates algorithm/image updates across all regions
- **Lateral promotion** for EU emergency fixes reaching Asia before Tokyo market open
- **Multi-cluster** deployment with one worker per regional cluster

For detailed explanations of ConfigHub concepts, see [docs.confighub.com](https://docs.confighub.com).
