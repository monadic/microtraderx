# Proposed Updates to CLAUDE.md

Based on session 2025-10-06: Mini TCK implementation, MicroTraderX unique prefix, CLI syntax discoveries.

---

## Section to Add: "Mini TCK for ConfigHub + Kubernetes Testing"

Add after the "Comprehensive Testing Requirements" section:

```markdown
### Mini TCK (Technology Compatibility Kit)

**Location**: `/Users/alexis/Public/github-repos/devops-sdk/test-confighub-k8s`

**Purpose**: Minimal test verifying ConfigHub + Kubernetes integration works correctly.

**What It Tests:**
1. ✅ ConfigHub API connectivity and authentication
2. ✅ Kubernetes cluster creation (Kind)
3. ✅ ConfigHub space creation
4. ✅ ConfigHub unit creation
5. ⚠️ Worker installation (known issues - see below)
6. Unit apply workflow
7. Live state verification

**Usage:**
```bash
# From devops-sdk
cd /Users/alexis/Public/github-repos/devops-sdk
./test-confighub-k8s

# From traderx or microtraderx (wrapper scripts)
./test-confighub-k8s

# Standalone (no checkout needed)
curl -fsSL https://raw.githubusercontent.com/monadic/devops-sdk/main/test-confighub-k8s | bash
```

**What Gets Created:**
- 1 Kind cluster: `confighub-tck`
- 1 ConfigHub space: `confighub-tck`
- 1 ConfigHub unit: `test-pod-<timestamp>` (unique names prevent conflicts)
- 1 Worker: `tck-worker` (if worker installation succeeds)
- 1 Kubernetes pod: Running nginx

**Auto-Cleanup:** All resources deleted on exit (success or failure)

**Known Issues:**
- ⚠️ Worker installation with `--wait` flag may timeout or fail silently
- ✅ Steps 1-3 (cluster, space, unit) work reliably
- ❌ Step 4 (worker install) often fails with "BridgeWorker not found" error
- **Workaround**: Use manual worker installation or skip worker tests

**Documentation**: See `devops-sdk/TCK.md` for full details.
```

---

## Section to Add: "CRITICAL: Unique Prefix Pattern (MUST ALWAYS USE)"

Add after "Canonical ConfigHub Commands" section:

```markdown
### CRITICAL: Unique Prefix Pattern (MUST ALWAYS USE)

**Problem**: ConfigHub slug uniqueness is global or has caching. Deleted spaces/units may not be immediately reusable, causing "already exists" errors.

**Solution**: ALWAYS use unique prefixes via `cub space new-prefix` (like global-app pattern).

#### Implementation Pattern (REQUIRED for all projects):

**1. Create `bin/get-prefix` script:**
```bash
#!/bin/bash
PREFIX_FILE=".project-prefix"  # Change .project-prefix to your project name

if [ -f "$PREFIX_FILE" ]; then
  cat "$PREFIX_FILE"
else
  PREFIX=$(cub space new-prefix)
  echo "$PREFIX" > "$PREFIX_FILE"
  echo "$PREFIX"
fi
```

**2. Use in all scripts:**
```bash
#!/bin/bash
PREFIX=$(bin/get-prefix)
echo "📛 Using prefix: $PREFIX"

# Use PREFIX in all space names
cub space create ${PREFIX}-myapp
cub space create ${PREFIX}-myapp-dev
cub space create ${PREFIX}-myapp-prod

# Use PREFIX in worker names
cub worker create ${PREFIX}-worker --space ${PREFIX}-myapp
```

**3. Add to .gitignore:**
```
.project-prefix
.microtraderx-prefix
.traderx-prefix
```

#### Example: MicroTraderX Implementation

See `/Users/alexis/microtraderx/bin/get-prefix` for reference implementation.

**Before (WRONG - causes conflicts):**
```bash
cub space create traderx
cub space create traderx-dev
# Error: "A Space with the same value already exists"
```

**After (CORRECT - uses unique prefix):**
```bash
PREFIX=$(bin/get-prefix)  # e.g., "tail-tracks"
cub space create ${PREFIX}-traderx      # tail-tracks-traderx
cub space create ${PREFIX}-traderx-dev  # tail-tracks-traderx-dev
# Success! No conflicts!
```

#### Benefits:
- ✅ No "already exists" errors
- ✅ Multiple users can share ConfigHub account
- ✅ Each installation gets unique namespace
- ✅ Easy to identify your resources
- ✅ Prefix persists across script runs (stored in file)

**This pattern is MANDATORY for all new projects.**
```

---

## Section to Update: "Canonical ConfigHub Commands"

Replace existing "Canonical ConfigHub Commands" section with:

```markdown
### Canonical ConfigHub Commands (Verified Working)

Based on global-app, acmetodo, and actual testing.

#### Unique Prefix (ALWAYS REQUIRED)
```bash
# MUST be first command in any project setup
PREFIX=$(cub space new-prefix)  # e.g., "chubby-paws"
echo "$PREFIX" > .project-prefix

# Or use bin/get-prefix helper (recommended)
PREFIX=$(bin/get-prefix)
```

#### Space and Unit Creation
```bash
# Create spaces with unique prefix
cub space create ${PREFIX}-base
cub space create ${PREFIX}-dev --label environment=dev

# Create units - NOTE: positional args, not --data flag!
cub unit create \
  --space ${PREFIX}-base \
  --label type=app \
  reference-data \
  k8s/reference-data.yaml

# WRONG: cub unit create --data k8s/file.yaml reference-data --space ${PREFIX}-base
# RIGHT: cub unit create --space ${PREFIX}-base reference-data k8s/file.yaml
```

#### Upstream/Downstream (Canonical Pattern)
```bash
# Create downstream units with inheritance
# Use --upstream-space and slug, NOT unit IDs!

# CORRECT (canonical from acmetodo):
cub unit create reference-data \
  --space ${PREFIX}-dev \
  --upstream-space ${PREFIX}-base \
  --upstream-unit reference-data \
  --data k8s/reference-data.yaml

# WRONG (fragile, not canonical):
base_id=$(cub unit get --space ${PREFIX}-base --json reference-data | jq -r '.id')
cub unit create --space ${PREFIX}-dev reference-data \
  --upstream-unit $base_id \
  --data k8s/reference-data.yaml
```

#### Filters and Bulk Operations
```bash
# Create filters for targeting
cub filter create all Unit \
  --where-field "Space.Labels.project = '${PREFIX}'"

cub filter create app Unit \
  --where-field "Labels.type='app'"

# List units (NOTE: some commands don't support --format json)
cub unit list --space ${PREFIX}-dev

# Bulk update with push-upgrade
cub unit update --patch --upgrade --space "${PREFIX}-*"
```

#### Worker Installation
```bash
# Create and install worker
cub worker create ${PREFIX}-worker --space ${PREFIX}-dev

# Install to Kubernetes (may timeout with --wait flag)
cub worker install ${PREFIX}-worker \
  --space ${PREFIX}-dev \
  --namespace confighub \
  --export > worker.yaml

kubectl apply -f worker.yaml

# NOTE: --wait flag has known issues, use --export instead
```

#### Unit Apply
```bash
# Apply single unit
cub unit apply reference-data --space ${PREFIX}-dev

# Apply all units in space
cub unit apply --space ${PREFIX}-dev --where "*"
```
```

---

## Section to Add: "Known CLI Issues and Workarounds"

Add new section after "Canonical ConfigHub Commands":

```markdown
## Known CLI Issues and Workarounds

Based on actual testing with cub CLI (as of 2025-10-06).

### 1. Worker Installation with --wait Flag

**Issue**: `cub worker install --wait` often times out or fails silently.

```bash
# ❌ PROBLEMATIC:
cub worker install my-worker --space my-space --wait
# Error: "BridgeWorker 'my-worker' not found"
```

**Workaround**: Use `--export` and apply manually:
```bash
# ✅ RELIABLE:
cub worker install my-worker \
  --space my-space \
  --export > worker.yaml

kubectl apply -f worker.yaml
sleep 10  # Give worker time to connect
```

### 2. Unit Create Syntax (Positional Args)

**Issue**: Flags vs positional arguments confusion.

```bash
# ❌ WRONG (old syntax):
cub unit create --data k8s/app.yaml my-unit --space my-space

# ✅ CORRECT (current syntax):
cub unit create \
  --space my-space \
  --label type=app \
  my-unit \
  k8s/app.yaml
```

**Pattern**: `cub unit create [flags] <slug> <file>`

### 3. Upstream/Downstream with Unit IDs

**Issue**: Using unit IDs is fragile and not canonical.

```bash
# ❌ FRAGILE (not canonical):
base_id=$(cub unit get --space base --json myunit | jq -r '.id')
cub unit create --upstream-unit $base_id myunit k8s/myunit.yaml --space dev

# ✅ CANONICAL (from acmetodo):
cub unit create myunit \
  --space dev \
  --upstream-space base \
  --upstream-unit myunit \
  --data k8s/myunit.yaml
```

### 4. --format Flag Not Universal

**Issue**: Not all commands support `--format json`.

```bash
# ❌ May fail:
cub space list --format json

# ✅ Reliable (parse text output):
cub space list | grep myspace

# ✅ Or use jq when supported:
cub unit list --space myspace --format json | jq '.[].Slug'
```

### 5. Slug Uniqueness and Caching

**Issue**: Deleted spaces/units may not be immediately reusable.

```bash
# ❌ FAILS after deletion:
cub space delete myspace
cub space create myspace
# Error: "A Space with the same value already exists"
```

**Solution**: ALWAYS use unique prefixes (see "Unique Prefix Pattern" section).

### 6. Worker Uninstall Command

**Issue**: `cub worker uninstall` doesn't exist.

```bash
# ❌ DOES NOT EXIST:
cub worker uninstall my-worker --space my-space

# ✅ CORRECT:
cub worker delete my-worker --space my-space
kubectl delete deployment,secret -n confighub -l app=my-worker
```
```

---

## Section to Add: "Project Structure: TraderX vs MicroTraderX"

Add new section describing the two implementations:

```markdown
## Project Structure: TraderX vs MicroTraderX

Two related but distinct implementations for different audiences.

### MicroTraderX (Tutorial)

**Location**: `/Users/alexis/microtraderx`
**GitHub**: https://github.com/monadic/microtraderx
**Purpose**: Progressive tutorial teaching ConfigHub basics

**Characteristics:**
- 📖 7-stage progressive learning (Stage 1 → Stage 7)
- 🎯 Simple examples (1-2 services: reference-data, trade-service)
- 🔧 Core patterns only (spaces, units, push-upgrade)
- 🎓 Educational focus with clear explanations
- ⏱️ Complete in 30-60 minutes
- ✅ Uses unique prefix pattern (`bin/get-prefix`)
- ✅ Canonical upstream/downstream pattern (`--upstream-space`)

**Key Files:**
- `bin/get-prefix` - Generates unique prefix
- `setup-structure` - Creates ConfigHub structure (spaces, units)
- `deploy` - Deploys to Kubernetes (workers, apply)
- `stages/stage1-hello-traderx.sh` through `stage7-emergency-bypass.sh`
- `docs/LESSONS-FROM-ACMETODO.md` - What MicroTraderX learned

**Usage:**
```bash
cd /Users/alexis/microtraderx

# Pre-flight check
./test-confighub-k8s

# Run stages
./stages/stage1-hello-traderx.sh  # Creates PREFIX-traderx
./stages/stage4-push-upgrade.sh   # Demonstrates inheritance

# Or run specific stage
./setup-structure 3
./deploy 3
```

### TraderX (Production Example)

**Location**: `/Users/alexis/traderx`
**GitHub**: https://github.com/monadic/traderx
**Purpose**: Production-grade deployment of FINOS TraderX (9 services)

**Characteristics:**
- 🏢 Full 9-service FINOS application
- 🚀 Advanced ConfigHub features (Links, Filters, Bulk Ops, Functions)
- 🔗 Complex dependency management with placeholders + needs/provides
- 📊 Production-ready monitoring and validation
- 🎯 Real-world deployment scenarios
- ✅ ConfigHub Links pattern for dependencies
- ✅ Filter-based deployment (by layer)
- ✅ Bulk operations across environments

**Key Files:**
- `bin/install-base` - Creates project structure with filters
- `bin/install-envs` - Creates environment hierarchy
- `bin/create-links` - Establishes dependency links
- `bin/deploy-with-links` - Canonical deployment (automatic ordering)
- `bin/deploy-by-layer` - Layer-based deployment (infra → data → backend → frontend)
- `docs/LINKS-DEPENDENCIES.md` - Complete Links pattern documentation

**Usage:**
```bash
cd /Users/alexis/traderx

# Pre-flight check
./test-confighub-k8s

# Setup
bin/install-base      # Creates spaces, units, filters
bin/install-envs      # Creates dev/staging/prod hierarchy
bin/setup-worker dev  # Installs worker

# Deploy (Option 1: Links - RECOMMENDED)
bin/deploy-with-links dev

# Deploy (Option 2: Layer-based)
bin/deploy-by-layer dev
```

### Learning Path

**Recommended progression:**
1. **Start with MicroTraderX** - Learn ConfigHub basics
2. **Study docs/LESSONS-FROM-ACMETODO.md** - Understand advanced features
3. **Move to TraderX** - See production patterns
4. **Review TraderX docs/LINKS-DEPENDENCIES.md** - Master dependency management

### Key Differences

| Feature | MicroTraderX | TraderX |
|---------|-------------|---------|
| **Audience** | ConfigHub beginners | DevOps engineers |
| **Services** | 2 (reference-data, trade-service) | 9 (full FINOS app) |
| **Complexity** | LOW (progressive stages) | HIGH (production-ready) |
| **Dependencies** | None | Links + placeholders + needs/provides |
| **Patterns Used** | Spaces, Units, Push-upgrade | + Links, Filters, Bulk Ops, Functions |
| **Time to Complete** | 30-60 minutes | 2-3 hours |
| **Purpose** | Learn concepts | Deploy production app |
| **Deployment** | Simple worker + apply | Links-based or layer-based |

### Common Elements

Both use:
- ✅ Unique prefix pattern (global-app style)
- ✅ Canonical upstream/downstream (`--upstream-space`)
- ✅ ConfigHub-only commands (no direct kubectl)
- ✅ Two-script pattern (`setup-structure` vs `deploy`)
- ✅ Mini TCK for pre-flight checks
- ✅ Comprehensive documentation
```

---

## Section to Update: File Locations

Update the "Important File Locations" section to include:

```markdown
## Important File Locations

### Project Structure
```
/Users/alexis/
├── devops-as-apps-project/       # Planning and docs
│   ├── docs/                     # All planning documents
│   ├── .claude-code/            # Claude Code configuration
│   └── CLAUDE.md                # This file
│
├── Public/github-repos/
│   ├── devops-sdk/              # Reusable SDK
│   │   ├── test-confighub-k8s  # Mini TCK (CRITICAL for testing)
│   │   ├── TCK.md              # TCK documentation
│   │   ├── confighub.go        # Real ConfigHub client
│   │   ├── app.go              # Base app framework
│   │   └── go.mod              # Module: github.com/monadic/devops-sdk
│   │
│   ├── devops-examples/         # Example implementations
│   │   ├── drift-detector/     # Working drift detector
│   │   │   ├── main.go        # Uses Sets/Filters/informers
│   │   │   ├── main_test.go   # Unit tests
│   │   │   └── integration_test.go  # Real API tests
│   │   └── cost-optimizer/     # AI-powered cost optimization
│   │
│   └── confighub-examples/
│       └── global-app/          # CANONICAL reference (from ConfigHub team)
│           ├── bin/install-base
│           ├── bin/install-envs
│           └── bin/new-app-env
│
├── microtraderx/                # Tutorial version (LEARN HERE FIRST)
│   ├── bin/get-prefix          # Unique prefix generator
│   ├── setup-structure         # ConfigHub structure creation
│   ├── deploy                  # Kubernetes deployment
│   ├── stages/                 # 7 progressive stages
│   ├── test-confighub-k8s      # TCK wrapper
│   └── docs/
│       └── LESSONS-FROM-ACMETODO.md  # What we learned
│
└── traderx/                     # Production version (ADVANCED)
    ├── bin/
    │   ├── install-base        # Project setup
    │   ├── install-envs        # Environment hierarchy
    │   ├── create-links        # Dependency links
    │   ├── deploy-with-links   # Canonical deployment ⭐
    │   └── deploy-by-layer     # Layer-based deployment
    ├── test-confighub-k8s      # TCK wrapper
    └── docs/
        └── LINKS-DEPENDENCIES.md  # Links pattern (543 lines)
```
```

---

## Summary of Changes

1. **Added Mini TCK section** - Location, usage, known issues
2. **Added CRITICAL unique prefix pattern** - MUST ALWAYS USE for all projects
3. **Updated canonical commands** - Corrected CLI syntax, added verified patterns
4. **Added known CLI issues** - Worker installation, --format flag, positional args
5. **Added TraderX vs MicroTraderX** - Clear distinction, learning path, comparison
6. **Updated file locations** - Added microtraderx, traderx, TCK locations

## Files to Update in CLAUDE.md

1. Add "Mini TCK" section after testing requirements
2. Add "CRITICAL: Unique Prefix Pattern" section (high priority)
3. Replace "Canonical ConfigHub Commands" section with updated version
4. Add "Known CLI Issues and Workarounds" section
5. Add "Project Structure: TraderX vs MicroTraderX" section
6. Update "Important File Locations" section

All updates based on verified, working code from session 2025-10-06.
