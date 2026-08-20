# Keycloak realm export

`export_realm.sh` exports a Keycloak realm to a temporary Kubernetes PVC, copies
the files to a local directory, and removes its temporary Kubernetes resources.
By default, it writes exports below the ignored `keycloak/bin/dumps/` directory.

## Dev3

From the repository root, run:

```sh
./keycloak/bin/export/export_realm.sh --context dev3
```

The script targets the standard `default` namespace and `StackV` realm. It
requires an explicit Kubernetes context so an export cannot accidentally run
against the current context. Use `--help` to view its namespace, realm, output,
and temporary-storage options.

The script reads the deployed `keycloak-keycloakx` StatefulSet to use its exact
image, configured image-pull secrets (if any), database host, and database
secret reference. It then scales that StatefulSet to zero before exporting.
PostgreSQL remains running.
Keycloak is unavailable for the duration of the export; do not sync the Argo CD
application until the script has restored the StatefulSet and reported rollout
success.

The resulting directory defaults to `keycloak/bin/dumps/` and normally contains
`StackV-realm.json` plus one or more `StackV-users-*.json` files. Realm exports
contain sensitive identity data. This directory is ignored, but exports must
still be stored securely and never committed.

## Templates

The runner renders the following templates with `envsubst`:

- `realm-export-pvc.yaml` provisions the temporary `ReadWriteOnce` PVC.
- `realm-export-job.yaml` runs Keycloak's offline `kc.sh export` command.
- `realm-export-reader.yaml` mounts the completed export volume so `kubectl cp`
  can retrieve it.

If the runner exits unsuccessfully after creating export resources, it restores
Keycloak but deliberately leaves the temporary Job, Pod, or PVC in place for
inspection or manual recovery.
