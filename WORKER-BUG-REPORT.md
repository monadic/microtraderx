# ConfigHub Worker 404 Bug Report

## Summary

Worker pods crash immediately after deployment with a 404 error when trying to look up their own metadata from the ConfigHub API.

## Impact

- All `cub worker install` deployments fail
- MicroTraderX tutorial is blocked
- Any new worker deployments are non-functional

## Reproduction

### Quick Reproduction (Automated)
```bash
./reproduce-worker-bug.sh
```

### Manual Steps

1. Create a space and worker:
```bash
cub space create test-space
cub worker create test-worker --space test-space
```

2. Deploy worker to Kubernetes:
```bash
cub worker install test-worker --space test-space --export | kubectl apply -f -
```

3. Observe crash:
```bash
kubectl logs -n confighub -l app=test-worker
```

## Expected Behavior

Worker pod should:
1. Start successfully
2. Connect to ConfigHub API
3. Register itself and begin processing units

## Actual Behavior

Worker pod crashes with:
```
2025/10/05 20:50:46 [ERROR] Failed to get bridge worker slug: server returned status 404: 404 Not Found
2025/10/05 20:50:46 Error starting worker: failed to get bridge worker slug: server returned status 404: 404 Not Found
```

## Root Cause Analysis

### Worker Exists in ConfigHub ✅

Worker can be retrieved via CLI:
```bash
$ cub worker get test-worker --space test-space
ID              18f97d61-c767-470a-b871-8a85f34dbf13
Name            test-worker
Space           worker-bug-test-1759697439
Condition       Disconnected
```

### API Endpoint Returns 404 ❌

Direct API call fails:
```bash
$ curl -H "Authorization: Bearer $TOKEN" \
  https://hub.confighub.com/api/v1/bridge_workers/18f97d61-c767-470a-b871-8a85f34dbf13

{"message":"Not Found"}
```

### Image Digest Comparison

**Working worker** (created 2 days ago):
- Image: `ghcr.io/confighubai/confighub-worker:latest`
- Digest: `sha256:704352a1082163aee749c90b05223f882d8bacfd6e14981112b0d9f07b1d6fd0`
- Status: ✅ **Connected and working**

**New workers** (created today):
- Image: `ghcr.io/confighubai/confighub-worker:latest`
- Digest: `sha256:0af91d93059e2134b8297fbdce49b1bb7579914dd65cd28365b70b900fec6f55`
- Status: ❌ **Crashes with 404 error**

### Hypothesis

~~The worker pod is configured with the correct worker ID but the API endpoint doesn't exist.~~

**ACTUAL ROOT CAUSE**: The `:latest` worker image was updated and the new version has a regression:
1. Both image digests work when using the STREAM endpoint (`/api/bridge_worker/{id}/stream`)
2. The NEW image tries to call `/api/v1/bridge_workers/{id}` during startup, which returns 404
3. The OLD image (digest 704352a1) does not make this failing API call
4. **Note**: Even pinning to the old digest doesn't work - the cached image may have been updated

**This suggests a ConfigHub worker binary regression introduced between:**
- Old: `sha256:704352a1` (works)
- New: `sha256:0af91d93` (fails)

## Environment

- **ConfigHub CLI Version**:
  ```
  Client: fc44d933 (2025-09-29) → a9e49bab (2025-10-04)
  Server: 6c04a56ba
  ```
- **Worker Image**: `ghcr.io/confighubai/confighub-worker:latest`
- **Kubernetes**: kind cluster (local)

## Comparison with Working Worker

There is one working worker in the cluster:
```bash
$ kubectl get pods -n confighub
mellow-muzzle-traderx-worker-dev-c4c67d54b-2g5cb   1/1     Running   0   47h
```

This worker was created 47 hours ago, suggesting this may be a recent regression.

## Files

- `reproduce-worker-bug.sh` - Automated reproduction script
- `debug-worker-api.sh` - API endpoint debugging script

## Workaround

None currently. All new worker deployments fail.

## Next Steps

1. Check if API endpoint path has changed
2. Compare worker manifest from 47h ago vs now
3. Check if worker authentication mechanism changed
4. Test with different worker image versions

## Test Scripts

### Test 1: Verify Bug Reproduces
```bash
./reproduce-worker-bug.sh
```

Expected: Worker pod crashes with 404

### Test 2: Debug API Endpoints
```bash
./debug-worker-api.sh
```

Expected: API returns 404 for all bridge_workers endpoints

### Cleanup
```bash
# Clean up test resources
kubectl delete deployment -n confighub test-worker api-test-worker
cub space list | grep "worker.*test" | awk '{print $1}' | xargs -I {} cub space delete {}
```

## Related

- Issue affects all stages of MicroTraderX tutorial (1-7)
- Scripts have been updated to use latest CLI syntax
- All other ConfigHub operations work correctly (space, unit, target creation)
