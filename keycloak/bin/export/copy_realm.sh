#!/bin/bash
set -e
NAMESPACE=default

# Clean up any existing pod
kubectl --namespace $NAMESPACE delete pod tmp-reader 2>/dev/null || true

# Start temporary pod with PVC mounted
kubectl --namespace $NAMESPACE run tmp-reader --image=busybox --overrides='{"spec":{"containers":[{"name":"tmp-reader","image":"busybox","command":["sleep","3600"],"volumeMounts":[{"name":"export","mountPath":"/export"}]}],"volumes":[{"name":"export","persistentVolumeClaim":{"claimName":"keycloak-export-pvc"}}]}}'

# Wait for pod to be ready
echo "Waiting for pod to be ready..."
kubectl --namespace $NAMESPACE wait --for=condition=Ready pod/tmp-reader --timeout=60s

# Copy the files
mkdir -p ./dumps
kubectl cp $NAMESPACE/tmp-reader:/export/. ./dumps/import

# Clean up
kubectl delete pod tmp-reader