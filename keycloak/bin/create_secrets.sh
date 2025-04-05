#
# Modify and run the following to create the required password secret for Keycloak:
kubectl create secret generic keycloak-cred \
    --from-literal=admin-password='ADMIN_PASSWORD'
# --from-literal=postgres-password='DB_PASSWORD'
