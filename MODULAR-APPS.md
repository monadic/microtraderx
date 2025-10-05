# Modular DevOps Apps with ConfigHub

How to extend MicroTraderX with loosely-coupled DevOps applications that discover and integrate automatically.

---

## 🎯 The Problem: Adding DevOps Tools Shouldn't Break Your App

Traditional approaches require:
- Modifying your app's deployment files
- Adding dependencies and configurations
- Coordinating releases
- Managing version compatibility
- Creating custom integrations

**ConfigHub's solution**: Apps live in separate spaces and discover each other dynamically.

---

## 🏗️ MicroTraderX as a Modular Platform

### Current Architecture (Stages 1-7)

After completing the tutorial, you have:

```
traderx-base/                  # Shared configs
├── reference-data             # Market data service
└── trade-service             # Trading engine

traderx-prod-us/              # US region (3 replicas)
traderx-prod-eu/              # EU region (5 replicas)
traderx-prod-asia/            # Asia region (2 replicas)
```

### Adding DevOps Apps (Stage 8+)

Now let's add cost optimization WITHOUT touching TraderX:

```
cost-optimizer/               # Separate space!
├── analyzer                  # Discovers TraderX automatically
├── recommendations          # Stored as units
└── dashboard                # Web UI

security-scanner/            # Another separate space
├── scanner                  # Finds vulnerabilities
└── reports                  # Audit trail

drift-detector/              # Yet another space
├── detector                 # Monitors LiveState
└── corrector               # Fixes drift
```

---

## Stage 8: Add Cost Optimization (5 min)

### Step 1: Make TraderX Discoverable

```bash
# Add labels to existing services (one-time setup)
for region in us eu asia; do
  cub unit update trade-service --space traderx-prod-$region \
    --patch '{"Labels":{"app":"microtraderx","cost-optimizable":"true"}}'
  cub unit update reference-data --space traderx-prod-$region \
    --patch '{"Labels":{"app":"microtraderx","cost-optimizable":"true"}}'
done
```

### Step 2: Deploy Cost Optimizer (Separate App!)

```bash
# Create space for cost optimizer
cub space create cost-optimizer

# Create analyzer unit
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

### Step 3: Cost Optimizer Discovers MicroTraderX

```bash
# The cost optimizer runs this discovery:
cub unit list --space "*" \
  --where "Labels.app = 'microtraderx' AND Labels.cost-optimizable = 'true'"

# Output:
# traderx-prod-us/trade-service (replicas: 3)
# traderx-prod-eu/trade-service (replicas: 5)
# traderx-prod-asia/trade-service (replicas: 2)
# (plus reference-data in each region)
```

### Step 4: Apply Optimization (After Hours)

```bash
# EU market closed, reduce replicas
cub run set-replicas --replicas 1 \
  --space traderx-prod-eu \
  --unit trade-service

# Cost optimizer logs this as a unit
cub unit create optimization-2024-01-15 --space cost-optimizer \
  --data '{"saved":"$500/month","region":"eu","action":"scale-down"}'
```

✅ **Key Point**: MicroTraderX code unchanged. Cost optimizer discovered it dynamically!

---

## Stage 9: Add Security Scanner (3 min)

### Another Independent App

```bash
# Create security scanner space
cub space create security-scanner

# Deploy scanner
cub unit create scanner --space security-scanner --data scanner.yaml
cub unit apply scanner --space security-scanner

# Scanner discovers ALL deployments
cub unit list --space "*" \
  --where "Data CONTAINS 'kind: Deployment' AND Data CONTAINS 'image:'"

# Creates vulnerability report
cub unit create vuln-report-2024-01 --space security-scanner \
  --data '{"critical":0,"high":2,"medium":5}'
```

---

## Stage 10: Add Drift Detector (3 min)

### Yet Another Independent App

```bash
# Create drift detector space
cub space create drift-detector

# Drift detector compares Data vs LiveState
cub unit list --space "traderx-prod-*" \
  --columns Slug,Data,LiveState

# When drift detected, create correction
cub changeset create fix-drift
cub unit apply trade-service --space traderx-prod-us
cub changeset apply fix-drift
```

---

## 🔗 Loose Coupling Patterns

### 1. Discovery via WHERE Queries

```bash
# Find high-replica services across all apps
cub unit list --space "*" \
  --where "Data CONTAINS 'replicas:' AND
           Data NOT LIKE '%replicas: 1%' AND
           Data NOT LIKE '%replicas: 2%'"
```

### 2. Links for Relationships

```bash
# Link cost optimizer to services it monitors
cub link create cost-monitoring \
  traderx-prod-eu/trade-service \
  cost-optimizer/analyzer
```

### 3. Sets for Grouping

```bash
# Group critical services across apps
cub set create business-critical
cub set add-unit business-critical \
  traderx-prod-us/trade-service \
  traderx-prod-eu/trade-service \
  cost-optimizer/analyzer
```

### 4. Filters as Saved Queries

```bash
# MicroTraderX exposes a filter
cub filter create trading-services Unit \
  --where-field "Labels.app = 'microtraderx' AND
                 Slug LIKE '%trade-service%'" \
  --space traderx-base

# Other apps use it
cub unit list --filter traderx-base/trading-services --space "*"
```

---

## 🏗️ Complete Modular Architecture

After adding DevOps apps:

```
ConfigHub Spaces:
├── traderx-base/              # MicroTraderX base
├── traderx-prod-us/           # US trading (unchanged!)
├── traderx-prod-eu/           # EU trading (unchanged!)
├── traderx-prod-asia/         # Asia trading (unchanged!)
├── cost-optimizer/            # Cost analysis (new, separate)
├── security-scanner/          # Security (new, separate)
└── drift-detector/            # Drift monitoring (new, separate)

Relationships:
- cost-optimizer DISCOVERS traderx via WHERE
- security-scanner DISCOVERS all via WHERE
- drift-detector MONITORS traderx LiveState
- NO HARDCODED DEPENDENCIES!
```

---

## 💡 Why This Works

### Traditional Tools Can't Do This

**Helm**: Would need to modify charts, add dependencies
**Kustomize**: Would need to patch every overlay
**GitOps**: Would need to modify repos and coordinate
**Terraform**: Can't query across workspaces

### ConfigHub Makes It Natural

1. **Spaces = Module Boundaries**: Each app owns its space
2. **WHERE = Discovery**: Find resources without hardcoding
3. **No Modifications**: Original app stays untouched
4. **Dynamic Integration**: Apps find each other at runtime

---

## 🚀 Your Own DevOps App

### Template for New Apps

```bash
#!/bin/bash
# setup-my-devops-app

# 1. Create space
APP_NAME="my-devops-app"
cub space create $APP_NAME

# 2. Make discoverable
cat > app.yaml << EOF
metadata:
  labels:
    app: $APP_NAME
    discoverable: true
    capabilities: "monitoring,analysis"
EOF

cub unit create app --space $APP_NAME --data app.yaml

# 3. Discover MicroTraderX
TARGETS=$(cub unit list --space "*" \
  --where "Labels.app = 'microtraderx'")

# 4. Do something useful
for target in $TARGETS; do
  echo "Found: $target"
  # Your logic here
done

# 5. Store results as units
cub unit create results-$(date +%Y%m%d) \
  --space $APP_NAME \
  --data results.json
```

---

## 🎯 The Power: Composable Platform

### Start with MicroTraderX (Stages 1-7)
- Basic trading platform
- 3 regions, different scales
- Push-upgrade pattern

### Add DevOps Apps (Stages 8+)
- Cost optimization
- Security scanning
- Drift detection
- Performance monitoring
- Compliance checking
- Incident response

### Each App:
- Lives in its own space
- Discovers others via WHERE
- Integrates without modification
- Can be added/removed freely

---

## 📊 Example: Complete DevOps Platform

```bash
# Morning: Check overnight issues
cub unit list --space security-scanner --where "severity = 'critical'"
cub unit list --space drift-detector --where "status = 'drifted'"

# Business hours: Monitor costs
cub unit get latest-analysis --space cost-optimizer

# Market close: Scale down
for region in eu asia; do
  cub run set-replicas --replicas 1 \
    --space traderx-prod-$region \
    --unit trade-service
done

# All WITHOUT modifying MicroTraderX!
```

---

## 🎉 Summary

### What You Learned

1. **MicroTraderX stays simple** (2 services, 3 regions)
2. **DevOps apps are separate** (different spaces)
3. **Discovery is dynamic** (WHERE queries)
4. **Integration is loose** (no hardcoding)
5. **Platform grows naturally** (add apps anytime)

### Next Steps

Try adding your own DevOps app:
1. Pick a problem (backup, monitoring, alerting)
2. Create a new space
3. Discover MicroTraderX services
4. Do something useful
5. Store results as units

The MicroTraderX tutorial (Stages 1-7) + Modular Apps (Stages 8+) = Complete DevOps Platform!

---

## 🔗 Resources

- [README.md](README.md) - The 7-stage core tutorial
- [VISUAL-GUIDE.md](VISUAL-GUIDE.md) - See the architecture evolve
- [ARCHITECTURE.md](ARCHITECTURE.md) - Deep dive into patterns
- [QUICKSTART.md](QUICKSTART.md) - Run it yourself

**ConfigHub enables a true "DevOps App Store" where apps plug in and work together without modification!**