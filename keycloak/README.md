
# SENSE Keycloak

This chart installs a Keycloak server pre-configured with the SENSE theming and realm data on a K8s cluster, alongside an embedded PostgreSQL server.

## Configuration

This chart wraps around the Bitnami chart found at (https://artifacthub.io/packages/helm/bitnami/keycloak/24.7.4), and uses a custom Keycloak image to handle build optimization steps and realm packaging. In most cases you should be fine reviewing the variables established below from the full `values.yaml` and can copying or templating the `override.template.yaml` file as a base. You may also create your own override by copying from `values.yaml`. Either way, your first step will likely be to create a `override.yaml` and configure (at a minimum) the domain variables: `global.domain` and `ingress.hostname/authHostname`.

> This chart currently includes a custom ingress template due to legacy incompatibility with some of the Keycloak docker configurations. This will be resolved in a future update and this chart will transition into being a pure coniguration wrapper.

### Secrets

To initialize the admin user for the Keycloak server an existing secret is required. An example `kubectl` command can be found in `./bin/create_secrets.sh`. Remember to configure the override with the correct name if you change the default resource name.

Unless overridden, the chart assumes two accessible secrets, `{{ .Release.Name }}-auth` and `{{ .Release.Name }}-psql-auth`. The subcharts will initialize the KC admin and postgres user passwords according to the keys in those secrets; again, refer to `create_secrets.sh` for the specific field names and how to customize them.

## Installation

After creating the password secrets and configuring your override, run `helm install senseo-keycloak . [-f values.yaml] -f override.yaml`.

## Usage

Once ready, the Keycloak Admin Console should be accessible via the established ingress at an address similar to `https://keycloak.sense.es.net/auth/admin/`.

If the ingress was disabled or is non-functional, you can access the web console via port-forwarding with a command like `kubectl port-forward svc/senseo-kc-keycloak- 8282:8080`, which should make it available at ``.

## Parameters

### Global Parameters

| Name            | Description                                                                                          | Value            |
| --------------- | ---------------------------------------------------------------------------------------------------- | ---------------- |
| `global.domain` | The host domain. Can be used for the Ingress hostname such as `keycloak.{{ .Values.global.domain }}` | `example.es.net` |

### Common Parameters

| Name                | Description                      | Value |
| ------------------- | -------------------------------- | ----- |
| `namespaceOverride` | Override for the Helm namespace. | `nil` |

### PostgreSQL Parameters

| Name                                 | Description                                                                          | Value                           |
| ------------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------- |
| `postgres.enabled`                   | Whether to enable the included postgres deployment.                                  | `true`                          |
| `postgres.database`                  | The cluster init database name.                                                      | `keycloak`                      |
| `postgres.secret`                    | The secret with the database password specified.                                     | `{{ .Release.Name }}-psql-auth` |
| `postgres.generatePVC`               | If set to true, will generate a dynamic PVC. If set to false, `pvcName` must be set. | `true`                          |
| `postgres.pvcName`                   | Override for the PVC name.                                                           | `nil`                           |
| `postgres.pvcClass`                  | PVC class for the PSQL persistence.                                                  | `local-path`                    |
| `postgres.probes.startup.enabled`    | Whether to enable the default PSQL startup probe.                                    | `true`                          |
| `postgres.probes.startup.custom`     | A custom override for the PSQL startup probe.                                        | `{}`                            |
| `postgres.probes.liveness.enabled`   | Whether to enable the default PSQL liveness probe.                                   | `true`                          |
| `postgres.probes.liveness.custom`    | A custom override for the PSQL liveness probe.                                       | `{}`                            |
| `postgres.probes.readiness.enabled`  | Whether to enable the default PSQL readiness probe.                                  | `true`                          |
| `postgres.probes.readiness.custom`   | A custom override for the PSQL readiness probe.                                      | `{}`                            |
| `postgres.resources.requests.cpu`    | PSQL CPU request.                                                                    | `300m`                          |
| `postgres.resources.requests.memory` | PSQL memory request.                                                                 | `512Mi`                         |
| `postgres.resources.limits.cpu`      | PSQL CPU limit.                                                                      | `700m`                          |
| `postgres.resources.limits.memory`   | PSQL memory limit.                                                                   | `2Gi`                           |
| `postgres.nodeSelector`              | PSQL nodeSelector block.                                                             | `{}`                            |
| `postgres.tolerations`               | PSQL tolerations block.                                                              | `[]`                            |
| `postgres.affinity`                  | PSQL affinity block.                                                                 | `{}`                            |

### Custom Ingress Parameters

| Name                   | Description                                                                             | Value                                            |
| ---------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `ingress.enabled`      | Whether to enable the custom Ingress resource.                                          | `true`                                           |
| `ingress.className`    | The Ingress class.                                                                      | `traefik`                                        |
| `ingress.annotations`  | A dict of additional annotations, such as cert-manager Issuers.                         | `{}`                                             |
| `ingress.hostname`     | The hostname for the main and unfiltered admin endpoint. Can be templated.              | `keycloak.{{ .Values.global.domain }}`           |
| `ingress.authHostname` | The hostname for the limited auth endpoint, used by the Orchestrator. Can be templated. | `auth.{{ .Values.global.domain }}`               |
| `ingress.tlsSecret`    | Secret for the TLS credentials. Can be templated.                                       | `{{ .Release.Name }}-tls-keycloak`               |
| `issuer.enabled`       | Whether to enable the integrated cert-manager Issuer.                                   | `false`                                          |
| `issuer.name`          | Overrride for the Issuer name.                                                          | `nil`                                            |
| `issuer.email`         | Email metadata for the Issuer.                                                          | `example@gmail.com`                              |
| `issuer.server`        | Issuing server.                                                                         | `https://acme-v02.api.letsencrypt.org/directory` |
| `issuer.solvers`       | Override for the Issuer solvers.                                                        | `[]`                                             |
