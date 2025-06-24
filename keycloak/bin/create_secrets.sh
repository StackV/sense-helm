#
# Modify and run the following to create the required password secret for Keycloak:
kubectl create secret generic RELEASE_NAME-auth --from-literal=admin-password='ADMIN_PASSWORD'

#
# Modify and run the following to create the required password secret for PostgreSQL:
kubectl create secret generic RELEASE_NAME-psql-auth --from-literal=password='DB_PASSWORD'
