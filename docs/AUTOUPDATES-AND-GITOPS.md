# Notes on ConfigHub Auto-Updates and GitOps

> **ConfigHub Documentation**: For comprehensive two-state model and GitOps integration documentation, see [docs.confighub.com](https://docs.confighub.com). This document covers lessons learned about update vs apply behavior.

## Executive Summary

ConfigHub is by default more flexible than traditional GitOps. 

## Example

During TraderX deployment, we can run:

```bash
cub unit update account-service-deployment config.yaml --space dev
```

In this case Kubernetes pods will NOT restart with the new configuration. The pods continued running with old configuration until we explicitly ran:

```bash
cub unit apply account-service-deployment --space dev
```

## Why 

### ConfigHub links TWO states:

```
┌─────────────────────────────────────────────────────────────┐
│                                                               │
│  1. DESIRED STATE (in ConfigHub database)                    │
│     - Modified by: cub unit create, cub unit update, cub     │
│       unit patch                                              │
│     - View with: cub unit get <name> --space <space>         │
│     - This is the "source of truth"                           │
│                                                               │
│                                                               │
│  2. LIVE STATE (in Kubernetes/target infrastructure)         │
│     - Modified by: cub unit apply, cub unit destroy           │
│     - View with: cub unit get-live-state <name> --space      │
│       <space> or kubectl get                                  │
│     - This is the "running reality"                           │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

In default ConfigHub, updating desired state does not automatically update live state.  


## ConfigHub vs GitOps Comparison

### GitOps Tools (Flux, Argo):

```
Git Push → Auto-detect change → Auto-deploy → Continuous reconciliation
```

- Changes automatically sync to cluster
- Controllers continuously reconcile state
- No manual apply needed
- "Set it and forget it" model

### ConfigHub (Default Behavior):

```
cub unit update → Changes ConfigHub DB only
                ↓ (manual step required)
              cub unit apply → Deploys to infrastructure
```

- Changes stored but not deployed automatically
- Explicit apply required
- Controlled, intentional deployments
- "Review and release" model

## When Do Changes Auto-Deploy?

ConfigHub Workers can auto-apply changes, but only in specific scenarios:

### ✅ Auto-Applied by Worker:

1. **New units created and applied for first time**
   ```bash
   cub unit create my-service config.yaml --space dev
   cub unit apply my-service --space dev
   # Worker sees this and auto-applies future changes to THIS unit
   ```

2. **Image version changes via `cub run`**
   ```bash
   cub run set-image-reference --container-name web-gui \
     --image-reference :v1.2.3 --space dev
   # Worker auto-applies this change
   ```

3. **Push-upgrade operations**
   ```bash
   cub unit push-upgrade --from dev --to staging
   # Worker in staging sees new units and auto-applies
   ```

### ❌ NOT Auto-Applied (Requires Manual Apply):

1. **Updates to existing unit definitions**
   ```bash
   cub unit update my-service new-config.yaml --space dev
   # Pods keep running with old config!
   # Must run: cub unit apply my-service --space dev
   ```

2. **Direct file modifications**
   ```bash
   # Edit confighub/base/my-service.yaml
   # Nothing happens - ConfigHub doesn't watch files
   # Must run: cub unit update + cub unit apply
   ```

3. **Patch operations**
   ```bash
   cub unit patch my-service --patch '{"spec":{"replicas":3}}'
   # Updates ConfigHub but doesn't deploy
   # Must run: cub unit apply my-service --space dev
   ```

## Root Cause: Kubernetes Service Environment Variables

We also discovered that Kubernetes automatically injects environment variables for services:

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

## Best Practices for All ConfigHub Examples

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

### 2. Verify State Consistency

After any update, verify desired state matches live state:

```bash
# Check desired state (what ConfigHub thinks should be deployed)
cub unit get my-service --space dev --data-only > desired.yaml

# Check live state (what's actually running in Kubernetes)
cub unit get-live-state my-service --space dev > live.yaml

# Compare
diff desired.yaml live.yaml
```

### 3. Use Immutable Deployments for Versions

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

### 4. Deployment Script Pattern

All `bin/` deployment scripts should follow this pattern:

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

## Updated Canonical Patterns

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

### Pattern 3: Version Rollout (Preferred)

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

## Implications for DevOps Examples

### drift-detector

Must detect ConfigHub vs Kubernetes state mismatches:

```yaml
Drift Type: ConfigHub Desired State vs Kubernetes Live State
ConfigHub Unit: backend-api-deployment (revision 5, updated 2 hours ago)
Kubernetes: deployment/backend-api (revision 3, deployed yesterday)
Root Cause: ConfigHub unit updated but never applied to Kubernetes
Recommendation: cub unit apply backend-api-deployment --space dev
```

### Deployment Scripts

All deployment scripts must:
1. Update ConfigHub first
2. Apply to infrastructure second
3. Verify state consistency
4. Log both operations

Example from `bin/ordered-apply`:

```bash
info "Applying $service..."

# Update ConfigHub (desired state)
retry_with_backoff $MAX_RETRIES \
  "cub unit update ${service}-deployment --space $SPACE config.yaml"

# Apply to Kubernetes (live state)
retry_with_backoff $MAX_RETRIES \
  "cub unit apply ${service}-deployment --space $SPACE"

# Verify consistency
verify_state_consistency ${service}-deployment $SPACE
```

### Integration Tests

Must verify state consistency:

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

## Mental Model

Think of ConfigHub like **Git + Manual Deploy**:

```
Git:        git commit → git push → (CI/CD) → deploy
ConfigHub:  cub unit update → cub unit apply → infrastructure updates
```

**NOT like GitOps**:

```
GitOps:     git push → auto-sync → auto-deploy → continuous reconcile
ConfigHub:  cub unit update → (STOPS HERE until manual apply)
```

## Advantages of ConfigHub's Approach

1. **Explicit Control**: You decide when changes deploy
2. **Approval Gates**: Review changes before applying
3. **Change Windows**: Deploy during maintenance windows
4. **Blast Radius**: Test in dev before promoting
5. **Audit Trail**: Clear record of who applied what and when

## Disadvantages (and Mitigations)

1. **Manual Steps**: Can forget to apply
   - **Mitigation**: Always pair update + apply in scripts

2. **State Drift**: ConfigHub and infrastructure diverge
   - **Mitigation**: Use drift-detector to monitor

3. **Not Truly GitOps**: Doesn't auto-reconcile
   - **Mitigation**: Use workers with auto-apply for specific use cases

4. **Learning Curve**: Two-state model is unintuitive
   - **Mitigation**: This document + clear examples

## Recommendations for All Examples

### 1. Update Documentation

Every README.md must include:

```markdown
## ConfigHub State Management

ConfigHub uses a two-phase deployment model:

1. **Update** - Change desired state: `cub unit update`
2. **Apply** - Deploy to infrastructure: `cub unit apply`

**Important**: Updating ConfigHub does NOT automatically deploy to Kubernetes.
You must explicitly apply changes.

See [docs/AUTOUPDATES-AND-GITOPS.md](docs/AUTOUPDATES-AND-GITOPS.md) for details.
```

### 2. Update CLAUDE.md

Add to canonical patterns section:

```markdown
## ConfigHub Deployment Pattern (CRITICAL)

ConfigHub is NOT GitOps. Changes to ConfigHub state do not automatically deploy.

### Always Update + Apply:
```bash
cub unit update my-service config.yaml --space dev
cub unit apply my-service --space dev  # Required!
```

### Never Assume Auto-Deploy:
```bash
cub unit update my-service config.yaml --space dev
# Pods still running old config!
# Must run: cub unit apply my-service --space dev
```

See docs/AUTOUPDATES-AND-GITOPS.md for full explanation.
```

### 3. Update All Scripts

Every deployment script must follow update + apply pattern:

```bash
# Template for all deployment scripts
update_and_apply() {
  local unit=$1
  local space=$2
  local config=$3

  # Update ConfigHub
  cub unit update $unit --space $space $config

  # Apply to infrastructure
  cub unit apply $unit --space $space
}
```

### 4. Add Integration Tests

Every example must test state consistency:

```bash
# test/integration/test-state-consistency.sh
for unit in $(cub unit list --space dev --format json | jq -r '.[].Slug'); do
  if ! verify_state_consistency $unit dev; then
    echo "FAIL: $unit has ConfigHub vs Kubernetes state mismatch"
    exit 1
  fi
done
```

## Conclusion

ConfigHub provides **explicit control** over deployments, not **automatic reconciliation**. This is by design and has advantages, but requires discipline:

1. Always `apply` after `update`
2. Verify state consistency
3. Use drift-detector to monitor
4. Document this behavior clearly

Understanding this distinction is the difference between successful ConfigHub deployments and frustrating debugging sessions.

---

**Document Created**: 2025-10-06
**Discovered During**: TraderX deployment (sweet-growl-traderx)
**Key Insight**: `cub unit update` ≠ deployment; requires explicit `cub unit apply`
