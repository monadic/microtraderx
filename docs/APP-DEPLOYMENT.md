# MicroTraderX App Deployment

## Overview

The MicroTraderX tutorial example uses a two-script pattern that separates ConfigHub state management from Kubernetes deployment.  

## Two-Script Pattern

```
./setup-structure  →  Creates/updates ConfigHub desired state
./deploy           →  Applies desired state to Kubernetes
```

This maps directly to this model:

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
2. Review/approve changes - you can also use apply gates in ConfigHub
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

**Key Principle**: Updating desired state does **NOT** automatically update live state.

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
4. **Direct file modifications** - ConfigHub doesn't watch files

Let us know if you have questions or comments on this topic.

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

# Compare desired vs live
cub unit get trade-service --space dev --data-only > desired.yaml
cub unit get-live-state trade-service --space dev > live.yaml
diff desired.yaml live.yaml
```

## Comparison with GitOps

### GitOps (Flux, Argo):
```
Git Push → Auto-detect → Auto-deploy → Continuous reconcile
```
- No manual apply needed
- Changes deploy automatically
- Continuous drift correction
- "Set it and forget it" model

### ConfigHub (MicroTraderX Pattern):
```
setup-structure (update ConfigHub) → deploy (apply to K8s)
```
- Explicit control over deployment
- Review before applying
- Intentional, not automatic
- "Review and release" model

ConfigHub's motivation is to help users pick best practices and patterns, just like GitOps tools now do, but in a very explicit way.  Because you know exactly when changes deploy, you can get greater control and avoid certain surprises.  You can also test eg.: update ConfigHub, test locally, then deploy.  In production you can review changes before applying.  You can't accidentally update production.

## Best Practices

### 1. Always Update + Apply Together

```bash
# ❌ Wrong - only updates ConfigHub
cub unit update my-service config.yaml --space dev

# ✅ Correct - update AND deploy
cub unit update my-service config.yaml --space dev
cub unit apply my-service --space dev

# ✅ Best - atomic operation
cub unit update my-service config.yaml --space dev && \
  cub unit apply my-service --space dev
```

### 2. Use Immutable Deployments for Versions

Instead of updating configurations, change image tags:

```bash
# ❌ Avoid - mutable deployment
cub unit update my-service --patch '{"spec":{"template":{"spec":{"containers":[{"image":"my-app:v2"}]}}}}'
cub unit apply my-service --space dev

# ✅ Prefer - immutable image reference
cub run set-image-reference --container-name my-app \
  --image-reference :v2 --space dev
# Worker auto-applies this
```

### 3. Deployment Script Pattern

All deployment scripts should follow this pattern:

```bash
#!/bin/bash
set -euo pipefail

deploy_service() {
  local service=$1
  local space=$2

  echo "Deploying $service to $space..."

  # 1. Update desired state in ConfigHub
  if [ -f "confighub/base/${service}-deployment.yaml" ]; then
    cub unit update ${service}-deployment \
      --space $space \
      confighub/base/${service}-deployment.yaml
  fi

  # 2. Apply to infrastructure
  cub unit apply ${service}-deployment --space $space

  # 3. Verify deployment
  cub unit get-live-state ${service}-deployment --space $space

  # 4. Wait for readiness
  kubectl wait --for=condition=ready pod \
    -l app=$service -n namespace-$space --timeout=120s
}
```

### 4. State Consistency Tests

Integration tests should verify state consistency:

```bash
test_state_consistency() {
  local unit=$1
  local space=$2

  # Get desired state
  local desired=$(cub unit get $unit --space $space --data-only)

  # Get live state
  local live=$(cub unit get-live-state $unit --space $space)

  # Verify they match
  if ! diff <(echo "$desired") <(echo "$live"); then
    echo "ERROR: State mismatch detected"
    echo "Desired state in ConfigHub does not match live state in Kubernetes"
    return 1
  fi

  return 0
}
```

## Common Deployment Patterns

### Pattern 1: Configuration Update
```bash
# Update configuration
cub unit update backend-api config.yaml --space dev

# Deploy to target (REQUIRED - not automatic!)
cub unit apply backend-api --space dev

# Verify
cub unit get-live-state backend-api --space dev
```

### Pattern 2: Environment Promotion
```bash
# Update and test in dev
cub unit update backend-api config.yaml --space dev
cub unit apply backend-api --space dev
# Test...

# Promote to staging (creates new units with upstream relationship)
cub unit push-upgrade --from dev --to staging

# Apply to staging
cub unit apply backend-api --space staging
```

### Pattern 3: Version Rollout 
```bash
# Update image in dev
cub run set-image-reference \
  --container-name backend-api \
  --image-reference :v1.2.3 \
  --space dev
# Auto-applied by worker

# Promote to staging
cub run set-image-reference \
  --container-name backend-api \
  --image-reference :v1.2.3 \
  --space staging
# Auto-applied by worker
```

## Troubleshooting: Kubernetes Service Environment Variables

Kubernetes automatically injects environment variables for services, which can cause issues:

```bash
# Kubernetes auto-injects these:
ACCOUNT_SERVICE_PORT=tcp://10.96.25.141:18088
ACCOUNT_SERVICE_SERVICE_HOST=10.96.25.141
ACCOUNT_SERVICE_SERVICE_PORT=18088

# This breaks apps that expect simple port numbers
```

**Fix**: Add `enableServiceLinks: false` to pod spec:

```yaml
spec:
  enableServiceLinks: false  # Prevents Kubernetes service env var injection
  containers:
  - name: my-service
    env:
    - name: MY_SERVICE_PORT
      value: "8080"  # Simple value, not tcp://...
```

## Mental Models in this example

```
Git:        git commit → git push → (CI/CD) → deploy
ConfigHub:  cub unit update → cub unit apply → infrastructure updates
```


```
GitOps:     git push → auto-sync → auto-deploy → continuous reconcile
ConfigHub:  cub unit update → (STOPS HERE until manual apply)
```



## See Also

- [QUICKSTART.md](../QUICKSTART.md) - Running the tutorial
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture
- [TESTING.md](../TESTING.md) - Testing guide and validation

---

**Key Takeaway**: In MicroTraderX, `./setup-structure` prepares configuration, `./deploy` executes it. Both are required for changes to reach Kubernetes.
