# Replace $REMOTE_SVC with the source psql service.
pg_dump -C -h $REMOTE_SVC -U bn_keycloak bitnami_keycloak  | psql -h 127.0.0.1 -U keycloak bitnami_keycloak