# Extending MicroTraderX with Additional Applications

Experimental approach to adding auxiliary applications using separate ConfigHub spaces.

---

## Problem Statement

Traditional approaches require modifying deployment configurations, adding dependencies, coordinating releases, managing version compatibility, and creating custom integrations.

ConfigHub approach: Applications in separate spaces discover resources via WHERE queries.

---

## Base Configuration Structure

### Stages 1-7

```
traderx-base/
├── reference-data
└── trade-service

traderx-prod-us/
traderx-prod-eu/
traderx-prod-asia/
```

### Extension Pattern

Additional applications in separate spaces:

```
cost-optimizer/
├── analyzer
├── recommendations
└── dashboard

drift-detector/
├── detector
└── corrector
```

---

## Stage 8: Cost Optimization Application

### Label Base Resources

```bash
for region in us eu asia; do
  cub unit update trade-service --space traderx-prod-$region \
    --patch '{"Labels":{"app":"microtraderx","cost-optimizable":"true"}}'
  cub unit update reference-data --space traderx-prod-$region \
    --patch '{"Labels":{"app":"microtraderx","cost-optimizable":"true"}}'
done
```

### Deploy Analyzer

```bash
cub space create cost-optimizer

cat > cost-analyzer.yaml << 'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cost-analyzer
spec:
  schedule: "0 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: analyzer
            image: cost-optimizer:latest
            command: ["./discover-and-analyze"]
EOF

cub unit create analyzer --space cost-optimizer --data cost-analyzer.yaml
cub unit apply analyzer --space cost-optimizer
```

### Discovery Query

```bash
cub unit list --space "*" \
  --where "Labels.app = 'microtraderx' AND Labels.cost-optimizable = 'true'"
```

Returns:
- traderx-prod-us/trade-service
- traderx-prod-eu/trade-service
- traderx-prod-asia/trade-service
- reference-data units in each region

### Apply Optimization

```bash
cub run set-replicas --replicas 1 \
  --space traderx-prod-eu \
  --unit trade-service

cub unit create optimization-2024-01-15 --space cost-optimizer \
  --data '{"saved":"$500/month","region":"eu","action":"scale-down"}'
```

Result: Base MicroTraderX configuration unchanged.

---

## Stage 9: Drift Detection Application

```bash
cub space create drift-detector

cub unit list --space "traderx-prod-*" \
  --columns Slug,Data,LiveState

cub changeset create fix-drift
cub unit apply trade-service --space traderx-prod-us
cub changeset apply fix-drift
```

---

## Integration Patterns

### Discovery via WHERE Queries

```bash
cub unit list --space "*" \
  --where "Data CONTAINS 'replicas:' AND
           Data NOT LIKE '%replicas: 1%' AND
           Data NOT LIKE '%replicas: 2%'"
```

### Links for Relationships

```bash
cub link create cost-monitoring \
  traderx-prod-eu/trade-service \
  cost-optimizer/analyzer
```

### Sets for Grouping

```bash
cub set create business-critical
cub set add-unit business-critical \
  traderx-prod-us/trade-service \
  traderx-prod-eu/trade-service \
  cost-optimizer/analyzer
```

### Filters as Saved Queries

```bash
cub filter create trading-services Unit \
  --where-field "Labels.app = 'microtraderx' AND
                 Slug LIKE '%trade-service%'" \
  --space traderx-base

cub unit list --filter traderx-base/trading-services --space "*"
```

---

## Complete Structure

ConfigHub spaces after extension:

```
├── traderx-base/
├── traderx-prod-us/
├── traderx-prod-eu/
├── traderx-prod-asia/
├── cost-optimizer/
└── drift-detector/
```

Integration method:
- cost-optimizer discovers traderx via WHERE queries
- drift-detector monitors traderx LiveState
- No hardcoded dependencies between spaces

---

## Comparison with Traditional Approaches

Traditional tools:
- Helm: Requires chart modifications, dependency declarations
- Kustomize: Requires patching overlays
- GitOps: Requires repository modifications, coordination
- Terraform: Cannot query across workspaces

ConfigHub approach:
- Spaces provide module boundaries
- WHERE queries enable discovery without hardcoding
- Base application configuration unchanged
- Applications discover each other at runtime

---

## Application Template

```bash
#!/bin/bash

APP_NAME="my-devops-app"
cub space create $APP_NAME

cat > app.yaml << EOF
metadata:
  labels:
    app: $APP_NAME
    discoverable: true
    capabilities: "monitoring,analysis"
EOF

cub unit create app --space $APP_NAME --data app.yaml

TARGETS=$(cub unit list --space "*" \
  --where "Labels.app = 'microtraderx'")

for target in $TARGETS; do
  echo "Found: $target"
  # Application logic
done

cub unit create results-$(date +%Y%m%d) \
  --space $APP_NAME \
  --data results.json
```

---

## Example Operations

```bash
cub unit list --space drift-detector --where "status = 'drifted'"
cub unit get latest-analysis --space cost-optimizer

for region in eu asia; do
  cub run set-replicas --replicas 1 \
    --space traderx-prod-$region \
    --unit trade-service
done
```

---

## Summary

Pattern demonstrated:
- Base application (2 services, 3 regions)
- Extension applications (separate spaces)
- Discovery via WHERE queries
- Loose coupling (no hardcoding)

Implementation steps:
1. Create separate space
2. Discover target resources
3. Implement application logic
4. Store results as units

---

## Documentation References

- [README.md](README.md) - Core tutorial
- [VISUAL-GUIDE.md](VISUAL-GUIDE.md) - Visual progression
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical details
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick commands and setup