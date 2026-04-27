#!/bin/bash
set -e

# Clean up any existing pod
kubectl delete pod tmp-reader 2>/dev/null || true

# Start temporary pod with PVC mounted
kubectl run tmp-reader --image=busybox --overrides='{"spec":{"containers":[{"name":"tmp-reader","image":"busybox","command":["sleep","3600"],"volumeMounts":[{"name":"export","mountPath":"/export"}]}],"volumes":[{"name":"export","persistentVolumeClaim":{"claimName":"keycloak-export-pvc"}}]}}'

# Wait for pod to be ready
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/tmp-reader --timeout=60s

# Copy the files
mkdir -p ./dumps
kubectl cp default/tmp-reader:/export/. ./dumps/

# Clean up
kubectl delete pod tmp-reader