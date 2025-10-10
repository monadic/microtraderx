# Stages 4-7 Bug Fixes Applied

**Date**: 2025-10-10
**Status**: All fixes applied successfully (updated with Bug #20)

---

## Summary

Fixed 6 bugs in Stages 4-7:
- 3 code bugs (--patch inline JSON + --where "*" syntax)
- 3 documentation bugs (misleading examples)
- 1 potential bug verified as NOT a bug

---

## Bug #14: Stage 4 Setup Inline --patch ✅ FIXED

**File**: `setup-structure` (lines 160-165)
**Issue**: Regional customization commands used inline JSON with --patch flag

**Before**:
```bash
cub unit update trade-service --space ${PREFIX}-traderx-prod-us \
  --patch '{"spec":{"replicas":3}}' || true
cub unit update trade-service --space ${PREFIX}-traderx-prod-eu \
  --patch '{"spec":{"replicas":5}}' || true
cub unit update trade-service --space ${PREFIX}-traderx-prod-asia \
  --patch '{"spec":{"replicas":2}}' || true
```

**After**:
```bash
echo '{"spec":{"replicas":3}}' | cub unit update trade-service \
  --space ${PREFIX}-traderx-prod-us --patch --from-stdin || true
echo '{"spec":{"replicas":5}}' | cub unit update trade-service \
  --space ${PREFIX}-traderx-prod-eu --patch --from-stdin || true
echo '{"spec":{"replicas":2}}' | cub unit update trade-service \
  --space ${PREFIX}-traderx-prod-asia --patch --from-stdin || true
```

**Error Prevented**:
```
Failed: --patch requires one of: --from-stdin, --filename, --restore, --upgrade...
```

---

## Bug #19: Stage 7 Setup Inline --patch ✅ FIXED

**File**: `setup-structure` (lines 244-249)
**Issue**: Same as Bug #14 - regional customizations in Stage 7

**Before**:
```bash
cub unit update trade-service --space ${PREFIX}-traderx-prod-us \
  --patch '{"spec":{"replicas":3}}' || true
cub unit update trade-service --space ${PREFIX}-traderx-prod-eu \
  --patch '{"spec":{"replicas":5}}' || true
cub unit update trade-service --space ${PREFIX}-traderx-prod-asia \
  --patch '{"spec":{"replicas":2}}' || true
```

**After**:
```bash
echo '{"spec":{"replicas":3}}' | cub unit update trade-service \
  --space ${PREFIX}-traderx-prod-us --patch --from-stdin || true
echo '{"spec":{"replicas":5}}' | cub unit update trade-service \
  --space ${PREFIX}-traderx-prod-eu --patch --from-stdin || true
echo '{"spec":{"replicas":2}}' | cub unit update trade-service \
  --space ${PREFIX}-traderx-prod-asia --patch --from-stdin || true
```

**Error Prevented**: Same as Bug #14

---

## Bug #15: Stage 4 Deploy set-target WHERE ✅ VERIFIED NOT A BUG

**File**: `deploy` (line 200)
**Status**: No fix needed - command is correct

**Command**:
```bash
cub unit set-target worker-$region --space ${PREFIX}-traderx-prod-$region \
  --where "Slug != ''" || true
```

**Verification**: Checked `cub unit set-target --help`:
```
cub unit set-target <target-slug> --where "Slug LIKE 'app-%'"
      --where string    Filter expression using SQL-inspired syntax...
```

**Result**: ✅ `cub unit set-target` DOES support WHERE clause - command is correct

---

## Bug #20: WHERE "*" Invalid with --space ✅ FIXED (Found During Testing)

**File**: `deploy` (lines 201, 265, 283)
**Issue**: Using `--where "*"` with `--space` creates invalid SQL syntax

**Error**:
```
Failed: HTTP 400: invalid attribute name at `* AND SpaceID = '...'`
```

**Root Cause**: ConfigHub combines `--where "*"` with implicit space filter, creating `* AND SpaceID = '...'` which is invalid SQL.

**Locations Fixed**:
1. Line 201 (Stage 4): Regional deployments
2. Line 265 (Stage 7): Dev/staging deployments
3. Line 283 (Stage 7): Regional deployments

**Before**:
```bash
cub unit apply --space ${PREFIX}-traderx-prod-$region --where "*"
```

**After**:
```bash
cub unit apply --space ${PREFIX}-traderx-prod-$region --where "Slug != ''"
```

**Why Fix Works**: `"Slug != ''"` matches all non-empty units (equivalent intent to `"*"`) but is valid SQL that can be combined with space filter.

**Found**: During Stage 4 deployment testing after fixing Bugs #14-19

---

## Bug #16: Stage 4 Deploy Documentation ✅ FIXED

**File**: `deploy` (lines 207-208)
**Issue**: Example showed inline --patch syntax that won't work

**Before**:
```bash
echo "     cub unit update trade-service --space ${PREFIX}-traderx-base \\"
echo "       --patch '{\"spec\":{\"template\":{\"spec\":{\"containers\":[...]}}}}}'"
```

**After**:
```bash
echo "     echo '{\"spec\":{\"template\":{\"spec\":{\"containers\":[...]}}}}' | \\"
echo "       cub unit update trade-service --space ${PREFIX}-traderx-base --patch --from-stdin"
```

**Impact**: Users can now copy-paste working command

---

## Bug #17: Stage 6 Setup Documentation ✅ FIXED

**File**: `setup-structure` (lines 194-195)
**Issue**: Changeset example showed inline --patch syntax

**Before**:
```bash
echo "    cub unit update reference-data --space ${PREFIX}-traderx-prod-us --patch '{\"image\":\"v2\"}'"
echo "    cub unit update trade-service --space ${PREFIX}-traderx-prod-us --patch '{\"image\":\"v2\"}'"
```

**After**:
```bash
echo "    echo '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"reference-data\",\"image\":\"traderx/reference-data:v2\"}]}}}}' | \\"
echo "      cub unit update reference-data --space ${PREFIX}-traderx-prod-us --patch --from-stdin"
echo "    echo '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"trade-service\",\"image\":\"traderx/trade-service:v2\"}]}}}}' | \\"
echo "      cub unit update trade-service --space ${PREFIX}-traderx-prod-us --patch --from-stdin"
```

**Impact**: Correct syntax shown for changeset operations

---

## Bug #18: Stage 6 Deploy Documentation ✅ FIXED

**File**: `deploy` (lines 240-243)
**Issue**: Same as Bug #17 - changeset example with inline syntax

**Before**:
```bash
echo "  cub unit update reference-data --space ${PREFIX}-traderx-prod-us \\"
echo "    --patch '{\"spec\":{\"template\":{\"spec\":{\"containers\":[...]}}}}'"
echo "  cub unit update trade-service --space ${PREFIX}-traderx-prod-us \\"
echo "    --patch '{\"spec\":{\"template\":{\"spec\":{\"containers\":[...]}}}}'"
```

**After**:
```bash
echo "  echo '{\"spec\":{\"template\":{\"spec\":{\"containers\":[...]}}}}' | \\"
echo "    cub unit update reference-data --space ${PREFIX}-traderx-prod-us --patch --from-stdin"
echo "  echo '{\"spec\":{\"template\":{\"spec\":{\"containers\":[...]}}}}' | \\"
echo "    cub unit update trade-service --space ${PREFIX}-traderx-prod-us --patch --from-stdin"
```

**Impact**: Users can copy-paste working changeset commands

---

## Root Cause Analysis

### Pattern Identified
Same bug repeated in multiple stages (Bug #14 and #19 are identical).

### Why It Happened
- Likely copy-pasted from Stage 3 before Bug #11 was fixed
- Bug #11 (Stage 3 setup) had same issue: inline --patch
- Fix applied to Stage 3 wasn't propagated to Stages 4 & 7

### Lesson Learned
When fixing bugs in multi-stage tutorials:
1. Fix current stage
2. Search entire codebase for same pattern
3. Fix all instances proactively
4. Document pattern for future reference

---

## CLI Pattern Confirmed

### Data Modification Commands
All `cub unit update --patch` operations require input via stdin or file:

**Correct Patterns**:
```bash
# Via stdin (recommended)
echo '<json>' | cub unit update <unit> --patch --from-stdin

# Via file
cub unit update <unit> --patch --filename patch.json

# Via upgrade (no data needed)
cub unit update --patch --upgrade
```

**Wrong Pattern**:
```bash
# NEVER do this - will fail!
cub unit update <unit> --patch '<inline-json>'
```

---

## Files Modified

### Code Fixes
1. `setup-structure`
   - Lines 160-165 (Stage 4)
   - Lines 244-249 (Stage 7)

### Documentation Fixes
1. `deploy`
   - Lines 207-208 (Stage 4 examples)
   - Lines 240-243 (Stage 6 examples)

2. `setup-structure`
   - Lines 194-197 (Stage 6 examples)

---

## Testing Status

### Stage 4
- ⏳ Setup needs testing (Bug #14 fixed)
- ⏳ Deploy needs testing (Bug #15 verified OK)

### Stage 5
- ✅ No bugs found (examples only)

### Stage 6
- ✅ No code bugs (examples only)
- ✅ Documentation fixed

### Stage 7
- ⏳ Setup needs testing (Bug #19 fixed)
- ⏳ Deploy needs testing

---

## Next Steps

1. Test Stage 4 setup and deployment
2. Test Stage 7 setup and deployment
3. Verify all documentation examples are copy-pasteable
4. Document final results

---

## Comparison with Stage 3

### Stage 3 Bugs (Fixed Earlier)
- Bug #10: link create syntax
- Bug #11: patch inline → stdin (SAME PATTERN)
- Bug #12: cross-space links
- Bug #13: WHERE OR operator

### Stages 4-7 Bugs (Fixed Now)
- Bug #14: patch inline → stdin (SAME as #11)
- Bug #19: patch inline → stdin (SAME as #11)
- Bug #20: WHERE "*" with --space (NEW pattern - found during testing)
- Bugs #16-18: Documentation showing wrong syntax

**Total Bugs Fixed Across All Stages**: 19 (13 from Stages 1-3 + 6 from Stages 4-7)

---

**Status**: ✅ All identified bugs fixed, ready for testing
