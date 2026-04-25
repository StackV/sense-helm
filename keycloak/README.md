
# SENSE Keycloak

This chart installs a Keycloak server pre-configured with the SENSE theming and realm data on a K8s cluster, alongside an embedded PostgreSQL server.


> The below instructions are for the previous <= 0.8.0 versions. Details for the new 1.0 version will soon be referenced and mirrored from our official documentation site.  

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
