# ConfigHub MicroTraderX Tutorial

Learn ConfigHub fundamentals by building a simplified trading platform with multi-region deployment.

## 📚 Tutorial vs Production

**Tutorial: MicroTraderX** 
- Step by step examples teach the basics of ConfigHub apps 
- Core features: spaces, units, deployment, upgrade
- Option to showcase bulk ops and other extended capability


**Production: TraderX** 
- The [TraderX reference application from FINOS](https://github.com/finos/traderX) ported to [ConfigHub TraderX](https://github.com/monadic/traderx)
- Extended features: bulk operations, links, filters
- Dependency management, real world deployment patterns, monitoring and validation

We recommend you start with MicroTraderX to understand ConfigHub basics, then explore TraderX for production patterns.

---

## 📚 Documentation

### Getting Started
- **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - Quick commands, troubleshooting, and cleanup
- **[VISUAL-GUIDE.md](VISUAL-GUIDE.md)** - ASCII diagrams for each stage
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture, inheritance flow, and deployment patterns

### Additional Resources
- **[TESTING.md](TESTING.md)** - Testing guide and validation
- **[DOCS-MAP.md](DOCS-MAP.md)** - Documentation index and topic/persona navigation
- **[MODULAR-APPS.md](MODULAR-APPS.md)** - Extend MicroTraderX with "devops" apps 

---

## Important: how ConfigHub works in this example

ConfigHub supports multiple delivery and reconciliation models.  In this example we have split the work up into scripts as follows:

```
./setup-structure  →  updates desired (config) state in ConfigHub
./deploy           →  runs a worker to apply config changes to K8s
```

This means that running `./setup-structure` does NOT deploy to Kubernetes. You must run `./deploy` to apply changes.

If you have used [GitOps](https://opengitops.dev/) tools such as [FluxCD](https://fluxcd.io/) or [ArgoCD](https://argo-cd.readthedocs.io/), then you will be familiar with the idea that desired state changes can be immediately and automatically reconciled with the running state.  That means for example that when a configuration gets updated, the changes are deployed to Kubernetes.  ConfigHub can be set up to do this if you like, and has integration points for GitOps tools, KRM and Helm.  But it also lets you split up the GitOps 'flow' into smaller pieces.  This usage is consistent with modern practices eg. using the [FluxCD suspend function](https://fluxcd.io/flux/cmd/flux_suspend/).

If you are interested in this topic you can read more in **[docs/APP-DEPLOYMENT.md](docs/APP-DEPLOYMENT.md)** 


---

# Running the MicroTraderX example app

## Prerequisites

### Step 1: Install Docker

Docker is required to run Kubernetes locally.

**macOS:**
```bash
# Install Docker Desktop
brew install --cask docker

# Start Docker Desktop (or open from Applications)
open -a Docker

# Verify Docker is running
docker info
```

**Linux:**
```bash
# Install Docker Engine (Ubuntu/Debian)
curl -fsSL https://get.docker.com | sh
sudo systemctl start docker
sudo usermod -aG docker $USER  # Log out and back in after this
```

### Step 2: Create ConfigHub Account and Install CLI

```bash
# 1. Sign up for ConfigHub (free tier available)
open https://hub.confighub.com

# 2. Install ConfigHub CLI (macOS)
brew install confighubai/tap/cub

# 3. Login to ConfigHub
cub auth login
```

For Linux/Windows CLI installation, see [ConfigHub docs](https://docs.confighub.com/getting-started/).

### Step 3: Install Kubernetes (Kind)

Kind runs Kubernetes in Docker containers - perfect for local development.

```bash
# Install Kind
brew install kind    # macOS
# or: go install sigs.k8s.io/kind@latest

# Create a cluster
kind create cluster --name traderx

# Verify cluster is running
kubectl cluster-info --context kind-traderx
```

### Step 4: Optional Tools

```bash
# jq for JSON parsing (used in some examples)
brew install jq    # macOS
# or: apt install jq  # Linux
```

### Pre-Flight Check (Recommended)

Verify your complete setup before starting the tutorial:

```bash
curl -fsSL https://raw.githubusercontent.com/monadic/devops-sdk/main/test-confighub-k8s | bash
```

This runs a [Mini TCK](https://github.com/monadic/devops-sdk/blob/main/TCK.md) which tests:
- ✅ ConfigHub API connectivity
- ✅ Kubernetes (Kind) cluster access
- ✅ ConfigHub Worker installation and connection
- ✅ End-to-end apply workflow

You should see: `🎉 SUCCESS! ConfigHub + Kubernetes integration verified`

**If the check fails**, review the steps above. Common issues:
- Docker not running: `open -a Docker` (macOS) or `sudo systemctl start docker` (Linux)
- Kind cluster not created: `kind create cluster --name traderx`
- Not logged in to ConfigHub: `cub auth login`

See [TESTING.md](TESTING.md) for details.

## Quick Start

There are several options for running MicroTraderX:
1. Run all 7 stages in sequence
2. Run one stage only
3. Quick demo
4. Bulk operations intro

These are explained below.

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

### Option 4: Bulk Operations 
```bash
# After running stage 3 (multi-region):

# Scale all regions to 3 replicas at once
./bulk-operations 3 scale 3

# Update version across all regions
./bulk-operations 4 version v1.2.3

# Check status across all regions
./bulk-operations 3 status
```

See `./bulk-operations help` for more examples.

## Project Structure

```
microtraderx/
├── README.md                # This tutorial guide
├── QUICK-REFERENCE.md       # Quick commands and troubleshooting
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

## ConfigHub is a System of Record to configure your deployments

ConfigHub can act like a database for your config:

```bash
# SELECT: Query units like database rows
cub unit list --space "*" \
  --where "Slug = 'trade-service' AND Space.Slug LIKE '%prod%'" \
  --columns Name,Space.Slug,Data

# UPDATE: Modify units in place
cub unit update --space "*" \
  --where "Slug = 'trade-service'" \
  --patch '{"spec":{"replicas":3}}'

# INSERT: Create new units
cub unit create --space prod trade-service service.yaml

# DELETE: Remove units
cub unit delete trade-service --space dev
```

ConfigHub is also a versioned store:
- Every change is tracked (revisions)
- Changes are queryable (WHERE clauses)
- Changes are reversible (rollback to any revision)
- ConfigHub maintains **desired state** as source of truth
- Kubernetes reflects **executed state** after apply

## Core Implementation Pattern

We recommend using two primary scripts:

```bash
./setup-structure   # Create ConfigHub structure: spaces, units, relationships
./deploy           # Deployment to Kubernetes using config workers + apply
```

## Tutorial Stages

| Stage | Topic | Key Concept |
|-------|-------|-------------|
| 1 | Spaces, Units, Workers | Basic building blocks |
| 2 | Environments | Spaces as environments |
| 3 | Regional Scale | Business-driven configuration |
| 4 | Upgrade | Update base, preserve customizations |
| 5 | Find and Fix | SQL WHERE clauses |
| 6 | Atomic Updates | Changesets for related services |
| 7 | Emergency Fixes | Lateral promotion |

## Example Scenario: updating custom configs

The tutorial imagines a 'global trading platform' with region-specific scaling:

- US: 3 replicas (NYSE hours, normal volume)
- EU: 5 replicas (London + Frankfurt, peak trading)
- Asia: 2 replicas (Tokyo overnight, low volume)

Each region has a custom config.  We'd like push out a global update to the trading programs, while preserving regional replica counts.  Our solution uses ConfigHub which supports upgrades that understand and preserve local customizations.

---

## Stage 1: Hello TraderX

Spaces contain units. Workers deploy them to Kubernetes.

```bash
# setup-structure
cub space create traderx
cub unit create --space traderx reference-data reference-data.yaml

# deploy
cub worker install worker --space traderx --wait
cub unit apply reference-data --space traderx
```

```
traderx/
└── reference-data (market data service)
```



---

## Stage 2: Three Environments

Each environment can be a separate space. Copy operations promote configurations.

```bash
# setup-structure
for env in dev staging prod; do
  cub space create traderx-$env
  cub unit create --space traderx-$env reference-data \
    --upstream-space traderx --upstream-unit reference-data
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

---

## Stage 3: Regional Deployment with Links

Deploy three regions with infrastructure separation, service dependencies, and namespace isolation.

**New concept: Links**

Links express relationships between units:
- **Infrastructure links**: App units → namespace units (resolves `confighubplaceholder`)
- **Service dependencies**: trade-service → reference-data (deployment ordering)

**Why inheritance + links matter:**
- Shared configuration in base → all regions get same app version
- Regional customizations (replicas) stay independent
- Each region deploys to its own namespace (isolation)
- Services start in correct order (dependencies)
- Foundation for push-upgrade in Stage 4

```bash
# setup-structure
# Create base with shared configuration
cub space create traderx-base
cub unit create --space traderx-base reference-data reference-data.yaml
cub unit create --space traderx-base trade-service trade-service.yaml

# Create infrastructure space for namespaces
cub space create traderx-infra
cub unit create --space traderx-infra ns-base namespace-base.yaml

# Create regions with upstream relationships and links
for region in us eu asia; do
  cub space create traderx-prod-$region

  # Create app units (inherit from base)
  cub unit create reference-data \
    --space traderx-prod-$region \
    --upstream-space traderx-base \
    --upstream-unit reference-data

  cub unit create trade-service \
    --space traderx-prod-$region \
    --upstream-space traderx-base \
    --upstream-unit trade-service

  # Create namespace for this region
  cub unit create ns-$region \
    --space traderx-infra \
    --upstream-unit ns-base

  # Customize namespace name
  cub run set-string-path \
    --resource-type v1/Namespace \
    --path metadata.name \
    --attribute-value traderx-prod-$region \
    --unit ns-$region --space traderx-infra

  # Link apps to namespace (resolves confighubplaceholder)
  cub link create --space traderx-prod-$region \
    --from reference-data --to ns-$region --to-space traderx-infra

  cub link create --space traderx-prod-$region \
    --from trade-service --to ns-$region --to-space traderx-infra

  # Link service dependency (trade-service needs reference-data)
  cub link create --space traderx-prod-$region \
    --from trade-service --to reference-data
done

# Customize per region based on trading volume
cub unit update trade-service --space traderx-prod-us \
  --patch '{"spec":{"replicas":3}}'    # NYSE hours

cub unit update trade-service --space traderx-prod-eu \
  --patch '{"spec":{"replicas":5}}'    # Peak trading

cub unit update trade-service --space traderx-prod-asia \
  --patch '{"spec":{"replicas":2}}'    # Overnight

# deploy
# First deploy namespaces (infrastructure)
cub unit apply --space traderx-infra --where "*"

# Then deploy apps (links resolved, proper namespaces)
for region in us eu asia; do
  cub unit apply --space traderx-prod-$region --where "*"
done
```

Structure shows relationships:
```
traderx-base/                  # Shared app config
├── reference-data
└── trade-service
    ↓ upstream inheritance

traderx-infra/                 # Infrastructure
├── ns-us                      # Namespace for US
├── ns-eu                      # Namespace for EU
└── ns-asia                    # Namespace for Asia
    ↑ linked via Links

traderx-prod-us/               # US region
├── reference-data (→base, →ns-us)
└── trade-service (→base, →ns-us, →reference-data, replicas:3)
    Deploys to: traderx-prod-us namespace

traderx-prod-eu/               # EU region
├── reference-data (→base, →ns-eu)
└── trade-service (→base, →ns-eu, →reference-data, replicas:5)
    Deploys to: traderx-prod-eu namespace

traderx-prod-asia/             # Asia region
├── reference-data (→base, →ns-asia)
└── trade-service (→base, →ns-asia, →reference-data, replicas:2)
    Deploys to: traderx-prod-asia namespace
```

**Result**: Each region isolated in its own namespace, services start in correct order.

---

## Stage 4: Upgrade Pattern

Propagate base changes while preserving regional customizations.  Variants inherit from base via `--upstream-unit`. Upgrade propagates base changes while preserving variant customizations.

**Why base configurations exist:**
- Update application version in one place → flows to all variants
- Regional customizations (replicas) preserved during upgrades
- Single source of truth for shared configuration
- Without base: Must update each region manually, risking inconsistency

### ⚠️ Critical: Two-Phase Update

ConfigHub uses a two-phase update model:

1. **Update phase**: `cub unit update` changes ConfigHub database only
2. **Apply phase**: `cub unit apply` deploys to Kubernetes

**This means**: After `cub unit update --upgrade`, your config is updated but pods are still running the old version until you run `cub unit apply`.

```bash
# Create base + regions with inheritance
cub space create traderx-base
cub unit create --space traderx-base trade-service \
  trade-service-v1.yaml

for region in us eu asia; do
  cub unit create --space traderx-prod-$region trade-service \
    --upstream-unit traderx-base/trade-service  # Creates variants
done

# Regions already customized (from Stage 3)
# EU has 5 replicas for peak trading
# Asia has 2 for overnight

# Visualize variant hierarchy
cub unit tree --node=space trade-service --space "*"

# Critical update: New trade algorithm v2
cub unit update --space traderx-base trade-service \
  trade-service-v2.yaml  # New algorithm!

# Check which variants need upgrading
cub unit tree --node=space trade-service --space "*" \
  --columns Space.Slug,UpgradeNeeded

# Dry-run to preview changes before applying
cub unit update --dry-run --upgrade --patch --space "traderx-prod-us"

# Push upgrade (preserves regional replicas!)
cub unit update --upgrade --patch --space "traderx-prod-*"

# ⚠️ Config updated in ConfigHub, but NOT deployed yet!
# Kubernetes pods still running old version until you apply:
cub unit apply --space "traderx-prod-*" --where "*"
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


---

## Stage 5: Query and Filter Operations

WHERE clauses enable precise bulk operations across spaces. This is ConfigHub's operational pattern.

### The Operational Workflow

```bash
# Step 1: Query to identify target units
cub unit list --space "*" \
  --where "Slug = 'trade-service' AND Space.Slug LIKE '%prod%'" \
  --columns Name,Space.Slug,HeadRevisionNum

# Output shows exactly which units will be affected:
# NAME            SPACE                      HEAD-REVISION
# trade-service   traderx-prod-us            5
# trade-service   traderx-prod-eu            5
# trade-service   traderx-prod-asia          5

# Step 2: Update using the same WHERE clause
cub unit update --space "*" \
  --where "Slug = 'trade-service' AND Space.Slug LIKE '%prod%'" \
  --patch '{"spec":{"replicas":3}}'

# Step 3: Verify changes were made
cub unit list --space "*" \
  --where "Slug = 'trade-service' AND Space.Slug LIKE '%prod%'" \
  --columns Name,Space.Slug,HeadRevisionNum  # Revision incremented

# Step 4: Apply to Kubernetes
cub unit apply --space "*" \
  --where "Slug = 'trade-service' AND Space.Slug LIKE '%prod%'"
```

**Key Pattern**: Same WHERE clause for query → update → apply ensures you target the exact same set.

### Advanced: Reusable Filters

```bash
# Create named filter for common queries
cub filter create high-volume-trading Unit \
  --where-field "Data CONTAINS 'replicas:' AND replicas > 2"

# Use filter instead of WHERE clause
cub unit list --filter high-volume-trading --space "*"
cub unit update --filter high-volume-trading --space "*" --patch '...'
cub unit apply --filter high-volume-trading --space "*"
```

### ConfigHub Functions: Type-Safe Operations

The examples above use `--patch` with raw JSON. ConfigHub provides **functions** as a safer, more maintainable alternative:

```bash
# ❌ Raw patch (works but error-prone)
cub unit update trade-service --space prod-us \
  --patch '{"spec":{"replicas":3}}'

# ✅ Function (type-safe, self-documenting)
cub run set-replicas 3 --unit trade-service --space prod-us
```

**Why functions are better:**
- **Type-safe**: Validates inputs before applying
- **Self-documenting**: `set-replicas` is clearer than JSON patch path
- **Composable**: Functions can be chained and scripted
- **Consistent**: Same operation works across different resource types

**Common functions:**
```bash
# Update container image
cub run set-image-reference --container-name api --image-reference :v2.0 \
  --unit trade-service --space prod-us

# Set environment variable
cub run set-env-var --container-name api --env-var CIRCUIT_BREAKER --env-value true \
  --unit trade-service --space prod-eu

# Set resource limits
cub run set-container-resources --container-name api \
  --cpu 250m --memory 2Gi \
  --unit trade-service --space prod-asia
```

For operations without functions, use patches:
```bash
# Scale replicas (use patch, not function)
cub unit update trade-service --space prod-us \
  --patch '{"spec":{"replicas":3}}'

# Patches work with WHERE clauses too
cub unit update --space "*" \
  --where "Slug = 'trade-service' AND Space.Slug LIKE '%prod%'" \
  --patch '{"spec":{"replicas":3}}'
```

**When to use what:**
- **Functions**: Preferred for common operations (scale, env vars, images)
- **Patches**: Needed for complex or uncommon changes

---

## Stage 6: Update Multiple Services atomically ("all or none")

Changesets ensure related changes deploy together or not at all. Supports team coordination.

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


---

## Stage 7: Lateral Promotion eg. for fast critical changes

Lateral promotion enables emergency fixes to bypass normal promotion flow. Full revision history provides audit trail.

```bash
# Normal flow: dev → staging → us → eu → asia
# EU discovered critical trading bug at market open

# Emergency fix directly in EU
cub run set-env-var --container-name trade-service \
  --env-var CIRCUIT_BREAKER --env-value true \
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


---

## Complete System Structure

Use `cub unit tree` to visualize the config Variant Hierarchy:

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
- ConfigHub 'apps' can be long running in k8s connected to the config database

---

## Scripts: Setup and Deployment

Recall we are using two scripts.  Feel free to remix these in your own way.

### setup-structure
```bash
#!/bin/bash
# Create base space for shared configs
cub space create traderx-base
cub unit create --space traderx-base reference-data reference-data.yaml
cub unit create --space traderx-base trade-service trade-service.yaml

# Create regions with inheritance
for region in us eu asia; do
  cub space create traderx-prod-$region
  cub unit create --space traderx-prod-$region reference-data \
    --upstream-unit traderx-base/reference-data
  cub unit create --space traderx-prod-$region trade-service \
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

## Objectives

After completing this tutorial, you should be able to:

- Create ConfigHub spaces and units
- Deploy configurations to Kubernetes
- Manage multiple environments and regions
- Use push-upgrade to update globally while preserving local changes
- Query and fix configurations across regions with SQL WHERE clauses
- Perform atomic multi-service updates
- Handle emergency scenarios with lateral promotion


---

## Advanced ConfigHub Features (Not Covered)

This tutorial covered ConfigHub basics. For production-grade features, see the full [TraderX implementation](https://github.com/monadic/traderx).  We also have an [acmetodo example](https://docs.confighub.com/howto/acmetodo/).

**Interested in extending this tutorial?** See [docs/FUTURE-ENHANCEMENTS.md](docs/FUTURE-ENHANCEMENTS.md) for potential additions and advanced features roadmap.

### Features Demonstrated in This Tutorial ✅
- **Changesets** - Atomic operations across multiple units (Stage 6)
- **Filters** - Reusable query definitions (Stage 5)
- **Bulk Operations** - Update multiple regions simultaneously
- **Push-Upgrade** - Propagate base changes while preserving customizations (Stage 4)
- **Upstream/Downstream** - Inheritance via `--upstream-space` notation (Stages 4, 7)

### Advanced Features (See acmetodo/TraderX) 🚀

**1. Functions** - Reusable, safe operations (vs manual patches)
```bash
# Safer than manual JSON patches
cub run set-image-reference --container-name web --image-reference :v2 \
  --unit todo-app --space prod
cub run set-container-resources --container-name api --memory 16Gi \
  --unit todo-app --space prod
```

**2. Triggers** - Automatic validation before apply
```bash
# Ensure no placeholders before deployment
cub trigger create validate-complete Mutation "Kubernetes/YAML" no-placeholders

# Enforce production policies (replicas > 1)
cub trigger create replicated Mutation "Kubernetes/YAML" \
  cel-validate 'r.kind != "Deployment" || r.spec.replicas > 1'
```

**3. Approvals** - Governance workflows
```bash
# Require approval before prod deployment
cub trigger create require-approval Mutation "Kubernetes/YAML" is-approved 1
cub unit approve --space prod todo-app
```

**4. Links** - Dependency management with needs/provides
```bash
# Express service dependencies
cub link create trade-service-to-db \
  trade-service-deployment \
  database-deployment \
  --space traderx-dev

# ConfigHub auto-fills placeholders from linked units
# See: https://docs.confighub.com/entities/link/
```

**5. Sets** - Logical grouping for bulk operations
```bash
# Group related units
cub set create critical-services
cub set add critical-services trade-service reference-data
```

### Additional Capabilities

- **Cross-Space Inheritance** - Share configurations across space boundaries
- **Revision Management** - Complete change history with rollback
- **SDK and Integrations** - Go SDK, Helm, and more
- **[MODULAR-APPS.md](MODULAR-APPS.md)** - Extend MicroTraderX with "devops" apps 

See [docs.confighub.com](https://docs.confighub.com) for comprehensive documentation.

---

## What to Read

**Recommended learning path**:
1. Read this README for overview
2. Review [VISUAL-GUIDE.md](VISUAL-GUIDE.md) to see each stage
3. Study [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
4. Run the stages yourself with [QUICK-REFERENCE.md](QUICK-REFERENCE.md)

### Visual Progression
See [VISUAL-GUIDE.md](VISUAL-GUIDE.md) for command examples and ASCII before/after diagrams:
- Stage 1: Hello TraderX
- Stage 2: Three Environments
- Stage 3: Three Regions
- Stage 4: Push-Upgrade
- Stage 5: Find and Fix
- Stage 6: Atomic Updates
- Stage 7: Emergency Bypass

Each stage includes:
- ASCII art diagrams showing the structure
- Before/after visualizations
- Command examples
- Key concepts
- Real-world scenarios

### Architecture Diagrams
See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed visual diagrams:
- Complete system architecture (ConfigHub → Kubernetes)
- 3-region deployment topology (US, EU, Asia)
- Inheritance flow and upstream/downstream relationships
- Push-upgrade pattern (before/after)
- Emergency lateral promotion flow
- Multi-cluster deployment architecture

---


