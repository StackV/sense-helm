
# SENSE Keycloak

This chart installs a Keycloak server pre-configured with the SENSE theming and realm data on a K8s cluster, alongside an embedded PostgreSQL server.

## Configuration

This chart wraps around the Bitnami chart found at (https://artifacthub.io/packages/helm/bitnami/keycloak/9.8.1), and uses a custom Keycloak image to handle build optimization steps and realm packaging. In most cases you should be fine reviewing the variables established below from the full `values.yaml` and can copying or templating the `override.template.yaml` file as a base. You may also create your own override by copying from `values.yaml`. Either way, your first step will likely be to create a `override.yaml` and configure (at a minimum) the domain variables: `global.domain` and `ingress.hostname/authHostname`.

> This chart currently includes a custom ingress template due to legacy incompatibility with some of the Keycloak docker configurations. This will be resolved in a future update and this chart will transition into being a pure coniguration wrapper.

### Secrets

To initialize the admin user for the Keycloak server an existing secret is required. An example `kubectl` command can be found in `./bin/create_secrets.sh`. Remember to configure the override with the correct name if you change the default resource name.

Keycloak will initialize the `admin` user with the password set at `admin-password`, by default. Currently we do not expose the postgres DB password as this should not be modified, but if needed you can view the secrets templated by the helm subchart.

## Installation

After creating the password secret and configuring your override, run `helm install senseo-keycloak . [-f values.yaml] -f override.yaml`.

## Usage

Once ready, the Keycloak Admin Console should be accessible via the established ingress at an address similar to `https://keycloak.sense.es.net/auth/admin/`.

If the ingress was disabled or is non-functional, you can access the web console via port-forwarding with a command like `kubectl port-forward svc/senseo-kc-keycloak- 8282:8080`, which should make it available at ``.

## Parameters

### Global Parameters

| Name                        | Description                                                                                          | Value            |
| --------------------------- | ---------------------------------------------------------------------------------------------------- | ---------------- |
| `global.domain`             | The host domain. Can be used for the Ingress hostname such as `keycloak.{{ .Values.global.domain }}` | `example.es.net` |
| `global.secret.name`        | Secret for the Keycloak credentials.                                                                 | `keycloak-cred`  |
| `global.secret.passwordKey` | Secret key for the Keycloak admin password.                                                          | `admin-password` |

### Common Parameters

| Name                | Description                      | Value |
| ------------------- | -------------------------------- | ----- |
| `namespaceOverride` | Override for the Helm namespace. | `nil` |

### Custom Ingress Parameters

| Name                   | Description                                                                             | Value                                  |
| ---------------------- | --------------------------------------------------------------------------------------- | -------------------------------------- |
| `ingress.enabled`      | Whether to enable the custom Ingress resource.                                          | `true`                                 |
| `ingress.className`    | The Ingress class.                                                                      | `traefik`                              |
| `ingress.annotations`  | A dict of additional annotations, such as cert-manager Issuers.                         | `{}`                                   |
| `ingress.hostname`     | The hostname for the main and unfiltered admin endpoint. Can be templated.              | `keycloak.{{ .Values.global.domain }}` |
| `ingress.authHostname` | The hostname for the limited auth endpoint, used by the Orchestrator. Can be templated. | `auth.{{ .Values.global.domain }}`     |
| `ingress.tlsSecret`    | Secret for the TLS credentials. Can be templated.                                       | `{{ .Release.Name }}-tls-keycloak`     |
