# Start temporary pod with PVC mounted
kubectl run tmp-reader --image=busybox --overrides='{"spec":{"containers":[{"name":"tmp-reader","image":"busybox","command":["sleep","3600"],"volumeMounts":[{"name":"export","mountPath":"/export"}]}],"volumes":[{"name":"export","persistentVolumeClaim":{"claimName":"keycloak-export-pvc"}}]}}'

# Copy the file
kubectl cp default/tmp-reader:/export/. ./dumps/

# Clean up
kubectl delete pod tmp-reader