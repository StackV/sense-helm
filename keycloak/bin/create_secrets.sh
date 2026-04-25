#!/bin/bash

RELEASE_NAME="${1:-keycloak}"

#
# Modify and run the following to create the required password secret for Keycloak:
kubectl create secret generic "$RELEASE_NAME"-auth --from-literal=admin-password='ADMIN_PASSWORD'

#
# Modify and run the following to create the required connection secret for separate PostgreSQL connection:
kubectl create secret generic "$RELEASE_NAME"-psql-auth --from-literal=username='keycloak' --from-literal=admin-password='dbrootpass' --from-literal=password='dbpassword'