# MicroTraderX Quick Start

Quick reference for running the tutorial. See [README.md](README.md) for detailed explanations and concepts.

---

## Prerequisites

1. ConfigHub CLI: `cub upgrade`
2. ConfigHub Auth: `cub auth login`
3. Kubernetes: Local (kind/minikube) or remote cluster
4. jq: Optional but recommended

**Pre-Flight Check**: Run `curl -fsSL https://raw.githubusercontent.com/monadic/devops-sdk/main/test-confighub-k8s | bash` to verify setup

---

## Stage Overview

| Stage | What You Learn | Time |
|-------|----------------|------|
| 1 | Spaces, Units, Workers | 10 min |
| 2 | Environments as Spaces | 10 min |
| 3 | Regional Scale Customization | 15 min |
| 4 | Push-Upgrade Pattern | 20 min |
| 5 | Query and Filter Operations | 15 min |
| 6 | Atomic Changesets | 10 min |
| 7 | Emergency Bypass | 15 min |

**Total**: ~2 hours progressive learning

---

## Running the Tutorial

### Option 1: All Stages in Sequence
```bash
./stages/stage1-hello-traderx.sh
./stages/stage2-three-envs.sh
./stages/stage3-three-regions.sh
./stages/stage4-push-upgrade.sh
./stages/stage5-find-and-fix.sh
./stages/stage6-atomic-updates.sh
./stages/stage7-emergency-bypass.sh
```

### Option 2: Jump to Specific Stage
```bash
./setup-structure 4    # Create ConfigHub structure for stage 4
./deploy 4             # Deploy to Kubernetes
./test/validate.sh 4   # Validate deployment
```

### Option 3: Quick Demo (5 minutes)
```bash
./stages/stage1-hello-traderx.sh
kubectl get all -n traderx
```

See [README.md](README.md#quick-start) for more running options including bulk operations.

---

## Troubleshooting

### Check ConfigHub Structure
```bash
# List all spaces
cub space list

# List units in a specific space
cub unit list --space traderx-prod-us

# Get unit details
cub unit get trade-service --space traderx-prod-eu --output json | jq .

# View hierarchy
cub unit tree --node=space trade-service --space "*"

# Check upgrade status
cub unit tree --node=space trade-service --space "*" --columns Space.Slug,UpgradeNeeded
```

### Check Kubernetes Deployments
```bash
# List all traderx deployments
kubectl get deployments -A | grep traderx

# Check specific region
kubectl get all -n traderx-prod-eu

# Verify replica counts
kubectl get deploy trade-service -n traderx-prod-eu -o jsonpath='{.spec.replicas}'

# Check pod status
kubectl get pods -n traderx-prod-us -l app=trade-service

# View logs
kubectl logs -n traderx-prod-us -l app=trade-service --tail=50
```

### Common Issues

**"Unit not found"**
- Run `./setup-structure <stage>` first
- Verify with `cub unit list --space <space>`

**"Pods not starting"**
- Check ConfigHub applied: `cub unit get <unit> --space <space>`
- Check worker logs: `kubectl logs -n <namespace> -l app=confighub-worker`
- Verify target set: `cub unit list --space <space> --columns Name,Target.Slug`

**"Changes not deploying"**
- Remember: `cub unit update` changes config only
- Must run: `cub unit apply` to deploy
- See [docs/APP-DEPLOYMENT.md](docs/APP-DEPLOYMENT.md) for explanation

---

## Cleanup

### Remove ConfigHub Configuration
```bash
# Get your project prefix
PREFIX=$(bin/get-prefix)

# Delete base space
cub space delete ${PREFIX}-traderx-base

# Delete all production regions
for region in us eu asia; do
  cub space delete ${PREFIX}-traderx-prod-$region
done

# Delete dev/staging if created
cub space delete ${PREFIX}-traderx-dev
cub space delete ${PREFIX}-traderx-staging
```

### Remove Kubernetes Resources
```bash
# Get your project prefix
PREFIX=$(bin/get-prefix)

# Delete all namespaces
kubectl delete namespace ${PREFIX}-traderx-prod-us
kubectl delete namespace ${PREFIX}-traderx-prod-eu
kubectl delete namespace ${PREFIX}-traderx-prod-asia

# Or delete all traderx namespaces
kubectl get namespaces | grep traderx | awk '{print $1}' | xargs kubectl delete namespace
```

### Complete Cleanup
```bash
# Remove project tracking file
rm -f .cub-project

# Remove generated prefix
rm -f .prefix
```

---

## Next Steps

After completing the tutorial:

### Learn More
1. **[README.md](README.md)** - Read full stage explanations and concepts
2. **[VISUAL-GUIDE.md](VISUAL-GUIDE.md)** - Study ASCII diagrams showing config flow
3. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Deep dive into system architecture
4. **[CONFIGHUB-PATTERNS-REVIEW.md](CONFIGHUB-PATTERNS-REVIEW.md)** - Comprehensive ConfigHub patterns analysis (Grade: A+)
5. **[TESTING.md](TESTING.md)** - All 20 bugs fixed, known issues, CLI patterns reference
6. **[docs/APP-DEPLOYMENT.md](docs/APP-DEPLOYMENT.md)** - Understand setup vs deploy

### Experiment
- Change replica counts for different scenarios
- Add new services to the trading platform
- Try different environment hierarchies
- Modify regional customizations

### Build Your Own
Use MicroTraderX patterns to build your own ConfigHub application:
1. Start with two scripts: `setup-structure` and `deploy`
2. Use upstream/downstream for inheritance
3. Apply push-upgrade for propagation
4. Use WHERE clauses for bulk operations

### Advanced Features
When you're ready, explore:
- **[TraderX](https://github.com/monadic/traderx)** - Production patterns with 9 services
- **[Global-App](https://github.com/confighubai/examples/global-app)** - Canonical ConfigHub patterns
- **[docs/FUTURE-ENHANCEMENTS.md](docs/FUTURE-ENHANCEMENTS.md)** - Advanced ConfigHub features

---

## Quick Reference Commands

```bash
# Setup and deploy
./setup-structure <stage>
./deploy <stage>

# Validate
./test/validate.sh <stage>

# Bulk operations
./bulk-operations <stage> scale <replicas>
./bulk-operations <stage> status

# View structure
cub unit tree --node=space --space "*"

# Check status
cub unit list --space <space>
kubectl get all -n <namespace>

# Cleanup
cub space delete <space>
kubectl delete namespace <namespace>
```

---

**Start simple. Add complexity only when needed.**

For questions or issues, see [DOCS-MAP.md](DOCS-MAP.md) to find the right documentation.
