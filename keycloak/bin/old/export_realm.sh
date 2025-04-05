pod=$(kubectl get pods | grep keycloak-keycloak | awk '{print $1}')
kubectl exec -it $pod -- /opt/jboss/keycloak/bin/standalone.sh \
    -Djboss.socket.binding.port-offset=222 -Dkeycloak.migration.action=export \
    -Dkeycloak.migration.provider=singleFile \
    -Dkeycloak.migration.realmName=StackV \
    -Dkeycloak.migration.usersExportStrategy=REALM_FILE \
    -Dkeycloak.migration.file=/opt/jboss/manual-realm-export.json
