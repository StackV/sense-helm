#
# Modify and run the following to create the required password secret for Keycloak:
kubectl create secret generic RELEASE_NAME-auth --from-literal=admin-password='ADMIN_PASSWORD'

#
# Modify and run the following to create the required connection secret for separate PostgreSQL connection:
kubectl create secret generic RELEASE_NAME-psql-auth --from-literal=host='DB_HOST' \
    --from-literal=port='DB_PORT' \
    --from-literal=username='DB_USERNAME' \
    --from-literal=database='DB_DATABASE' \
    --from-literal=password='DB_PASSWORD' 


kubectl -n sense create secret generic new-keycloak-psql-auth --from-literal=host='new-keycloak-postgresql' \
    --from-literal=port='5432' \
    --from-literal=username='bn_keycloak' \
    --from-literal=database='bitnami_keycloak' \
    --from-literal=password='dbpassword' 