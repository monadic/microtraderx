# Proposed Updates to CLAUDE.md

Based on session 2025-10-06: Mini TCK location, CLI syntax corrections.

---

## Section to Add: "Mini TCK Location"

Add after the "Comprehensive Testing Requirements" section:

```markdown
### Mini TCK

**Location**: `/Users/alexis/Public/github-repos/devops-sdk/test-confighub-k8s`

**Usage:**
```bash
./test-confighub-k8s
```

**Documentation**: See `devops-sdk/TCK.md`
```

---

## Section to Update: "Canonical ConfigHub Commands"

Update the "Unit Create" section:

```markdown
#### Unit Creation

```bash
# Current CLI syntax
cub unit create --space my-space my-unit k8s/my-unit.yaml
```

#### Upstream/Downstream

```bash
# Use --upstream-space notation
cub unit create reference-data \
  --space dev \
  --upstream-space base \
  --upstream-unit reference-data \
  --data k8s/reference-data.yaml
```
```

---

## Summary

Two updates:
1. Mini TCK location
2. Corrected CLI syntax
