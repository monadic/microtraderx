# ConfigHub: Managing the MicroTraderX app

## Two-Script Pattern

MicroTraderX uses a two-script pattern that clearly separates ConfigHub state from Kubernetes deployment:

```
./setup-structure  →  Creates/updates ConfigHub desired state
./deploy           →  Applies desired state to Kubernetes
```

This maps directly to ConfigHub's two-state model:

```
┌────────────────────────────────────────────────┐
│  ConfigHub Database (Desired State)             │
│  Modified by: setup-structure                   │
│  Commands: cub space create, cub unit create,   │
│           cub unit update, cub unit patch        │
└────────────────────────────────────────────────┘
                    ↓
          (manual step - run ./deploy)
                    ↓
┌────────────────────────────────────────────────┐
│  Kubernetes Cluster (Live State)                │
│  Modified by: deploy                            │
│  Commands: cub worker install, cub unit apply   │
└────────────────────────────────────────────────┘
```

## Why Two Scripts?

### You control when changes deploy
Separating setup from deployment makes it obvious:
1. ConfigHub stores configuration (desired state)
2. Kubernetes runs workloads (live state)
... and you control the two.

### Experimentation
We invite you to try these features out and 'remix' them:
- Run `./setup-structure` multiple times to refine configuration
- Review changes in ConfigHub before deploying
- Use `cub unit get` to inspect desired state
- Deploy when ready with `./deploy`

### Production 
In production you might...
1. Update ConfigHub (via CI/CD, API, or CLI)
2. Review/approve changes
3. Deploy during maintenance window

## Stage-by-Stage Behavior

### Stage 1-2: Create & Apply
```bash
./setup-structure 1  # cub unit create reference-data
./deploy 1           # cub unit apply reference-data
```
Result: Fresh deployment

### Stage 3: Update & Apply
```bash
./setup-structure 3  # cub unit create + cub unit update (replicas)
./deploy 3           # cub unit apply --where "*"
```
Result: Updated replicas deployed

### Stage 4: Inheritance & Upgrade
```bash
./setup-structure 4  # cub unit create with --upstream-unit
./deploy 4           # cub unit apply all variants
# Later...
cub unit update trade-service --space traderx-base --patch '...'
cub unit update --upgrade --patch --space "traderx-prod-*"  # Propagate!
cub unit apply --space "traderx-prod-*" --where "*"         # Deploy!
```
Result: Base update propagated to all regions

## Updates Don't Auto-Deploy

```bash
# This only changes ConfigHub:
cub unit update trade-service --space traderx-prod-us \
  --patch '{"spec":{"replicas":10}}'

# Pods still running with old replica count!

# Must explicitly deploy:
cub unit apply trade-service --space traderx-prod-us

# Now pods update to 10 replicas
```

## Can Changes Deploy Automatically?

ConfigHub Workers can auto-apply.  In this example app:

### ✅ Auto-Applied:
1. **First-time apply** - Worker sees new unit, auto-applies future changes
2. **Image version changes** - `cub run set-image-reference` triggers worker
3. **Push-upgrade** - New variants from base trigger worker

### ❌ NOT Auto-Applied:
1. **Updates to existing units** - Must manually apply
2. **Patch operations** - ConfigHub updated, not Kubernetes
3. **Configuration changes** - Need explicit apply

Let us know if you have questions or comemtns on this topic.

## Tutorial Advice

### Always Run Both Scripts Together
```bash
# ✅ Correct
./setup-structure 3
./deploy 3

# ❌ Wrong - configuration not deployed
./setup-structure 3
# (forgot to run deploy)
```

### Re-Run Both When Making Changes
```bash
# Make a change
cub unit update trade-service --space traderx-prod-us \
  --patch '{"spec":{"replicas":10}}'

# Re-run deploy to apply
./deploy 3
```

### Or Use Update + Apply Pattern
```bash
# Alternative: Do both in one command
cub unit update trade-service --space traderx-prod-us \
  --patch '{"spec":{"replicas":10}}'  && \
cub unit apply trade-service --space traderx-prod-us
```

## Verifying State Consistency

Check if ConfigHub matches Kubernetes:

```bash
# Check desired state (what ConfigHub has)
cub unit get trade-service --space traderx-prod-us --data-only

# Check live state (what Kubernetes has)
cub unit get-live-state trade-service --space traderx-prod-us

# Or check Kubernetes directly
kubectl get deployment trade-service -n traderx-prod-us -o yaml
```

## Comparison with GitOps

### GitOps (Flux, Argo):
```
Git Push → Auto-detect → Auto-deploy → Continuous reconcile
```
- No manual apply needed
- Changes deploy automatically
- Continuous drift correction

### ConfigHub (MicroTraderX Pattern):
```
setup-structure (update ConfigHub) → deploy (apply to K8s)
```
- Explicit control over deployment
- Review before applying
- Intentional, not automatic

ConfigHub's motivation is to help users pick best practices and patterns, just like GitOps tools now do, but in a very explicit way.  Because you know exactly when changes deploy, you can get greater control and avoid certain surprises.  You can also test eg.: update ConfigHub, test locally, then deploy.  In produciton you can review changes before applying.  You can't accidentally update production. 


## See Also

- [AUTOUPDATES-AND-GITOPS.md](AUTOUPDATES-AND-GITOPS.md) - Comprehensive explanation of ConfigHub's state model
- [QUICKSTART.md](../QUICKSTART.md) - Running the tutorial
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture

---

