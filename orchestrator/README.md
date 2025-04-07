
# SENSE Orchestrator

This chart installs the SENSE Orchestrator on a K8s cluster, alongside an embedded MySQL server.

## Configuration

In most cases you should be fine reviewing the variables established below from the full `values.yaml` and copying or templating the `override.template.yaml` file as a base. You can also create your own override by copying from `values.yaml`. Either way, you should create a `override.yaml`, and configure (at a minimum) the two domain variables: `global.domain` and `global.keycloak` variables.

Depending on your cluster you will likely need to adjust the persistence variables under `mysql`, as well as the configuration of the Ingress and any TLS credentials.

### Secrets

The orchestrator relies on a set of two secrets that will need to be present before installing the chart. Example `kubectl` commands can be found in `./bin/create_secrets.sh`. Remember to configure your override with the correct names if you change the defaults.

- `.Values.global.credSecret` (Default `sense-cred`): Various passwords and credentials used by the orchestrator are set here, namely passwords for the database, client TLS and SMTP.
- `.Values.tls.keystoreSecret` (Default `sense-keystores`): The orchestrator uses a JKS keystore to enable client-based TLS for supported RMs. These are stored in binary data at the `client.keystore` key.

## Installation

After creating the required secrets and configuring your override, run `helm install senseo . [-f values.yaml] -f override.yaml`.

## Usage

Once ready, the Orchestrator should be accessible via the established ingress at an address similar to `https://{{ingress.hostname or global.domain}}/StackV-web/portal/`.

If the ingress was disabled or is non-functional, you can access the orchestrator via port-forwarding with a command like `kubectl port-forward svc/senseo-orchestrator 8282:8080`, which should make it available at `http://localhost:8282/StackV-web/portal`.

Once you reach the web portal, you will be redirected to the configured Keycloak instance, where you may login and begin using the orchestrator.

## Parameters

### Global Parameters

| Name                | Description                                                                                       | Value                 |
| ------------------- | ------------------------------------------------------------------------------------------------- | --------------------- |
| `global.namespace`  | The target namespace.                                                                             | `sense`               |
| `global.mode`       | If set to 'test', enables CD test server behavior (seed/reset SQL DB with integration test data). | `prod`                |
| `global.domain`     | The host domain for the orchestrator.                                                             | `stackv.sense.es.net` |
| `global.keycloak`   | The domain of an active Keycloak instance, used for authentication.                               | `auth.sense.es.net`   |
| `global.credSecret` | Secret name for the chart's basic credentials.                                                    | `sense-cred`          |

### Orchestrator Parameters

| Name                               | Description                                                                                                                              | Value                        |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| `image.repo`                       | Orchestrator image.                                                                                                                      | `virnao/stackv-orchestrator` |
| `image.tag`                        | Image tag to pull.                                                                                                                       | `latest`                     |
| `image.pullSecrets`                | Secrets for any private docker registry access.                                                                                          | `nil`                        |
| `ingress.enabled`                  | Whether to enable the ingress resource.                                                                                                  | `true`                       |
| `ingress.className`                | Ingress class.                                                                                                                           | `traefik`                    |
| `ingress.hostname`                 | Explicit host to be used for the ingress. Defaults to `domain` if unset.                                                                 | `nil`                        |
| `ingress.annotations`              | Ingress annotations.                                                                                                                     | `nil`                        |
| `ingress.tlsSecret`                | TLS secret name for ingress termination.                                                                                                 | `tls-stackv-orchestrator`    |
| `resources.requests.cpu`           | Orchestrator CPU request.                                                                                                                | `2000m`                      |
| `resources.requests.memory`        | Orchestrator memory request.                                                                                                             | `8Gi`                        |
| `resources.limits.cpu`             | Orchestrator CPU limit.                                                                                                                  | `16000m`                     |
| `resources.limits.memory`          | Orchestrator memory limit.                                                                                                               | `64Gi`                       |
| `service.type`                     | Orchestrator service type.                                                                                                               | `ClusterIP`                  |
| `service.ports.http`               | Orchestrator HTTP port.                                                                                                                  | `8080`                       |
| `service.ports.https`              | Orchestrator HTTPS port.                                                                                                                 | `8443`                       |
| `service.ports.debug.enabled`      | If set to `true`, will enable a set of debug and management ports.                                                                       | `false`                      |
| `service.ports.debug.consoleHttp`  | Wildfly HTTP port.                                                                                                                       | `9990`                       |
| `service.ports.debug.consoleHttps` | Wildfly HTTPS port.                                                                                                                      | `9993`                       |
| `service.ports.debug.debugger`     | Wildfly debug port.                                                                                                                      | `8787`                       |
| `nodeSelector`                     | Orchestrator nodeSelector block.                                                                                                         | `{}`                         |
| `tolerations`                      | Orchestrator tolerations block.                                                                                                          | `[]`                         |
| `affinity`                         | Orchestrator affinity block.                                                                                                             | `{}`                         |
| `tls.passwordKey`                  | Key of the password for the orchestrator keystore files, found in `.global.credSecret`.                                                  | `tls-password`               |
| `tls.keystoreSecret`               | Name of Kubernetes secret for the orchestrator keystore files. If unset, will automatically create the secret and set default keystores. | `sense-keystores`            |

### MySQL Parameters

| Name                              | Description                                                                                        | Value            |
| --------------------------------- | -------------------------------------------------------------------------------------------------- | ---------------- |
| `mysql.passwordKey`               | Key of the password for the mysql database, found in `.global.credSecret`.                         | `mysql-password` |
| `mysql.generatePVC`               | If set to true, will generate a dynamic PVC. If set to false, pvcName should almost always be set. | `true`           |
| `mysql.pvcName`                   | PVC name.                                                                                          | `mysql-pvc`      |
| `mysql.pvcClass`                  | PVC class for the mysql persistence.                                                               | `local-path`     |
| `mysql.resources.requests.cpu`    | MySQL CPU request.                                                                                 | `300m`           |
| `mysql.resources.requests.memory` | MySQL memory request.                                                                              | `1Gi`            |
| `mysql.resources.limits.cpu`      | MySQL CPU limit.                                                                                   | `1000m`          |
| `mysql.resources.limits.memory`   | MySQL memory limit.                                                                                | `4Gi`            |
| `mysql.nodeSelector`              | MySQL nodeSelector block.                                                                          | `{}`             |
| `mysql.tolerations`               | MySQL tolerations block.                                                                           | `[]`             |
| `mysql.affinity`                  | MySQL affinity block.                                                                              | `{}`             |

### SMTP Parameters

| Name               | Description                                                                                                         | Value                 |
| ------------------ | ------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `mail.host`        | Host of an external SMTP server for orchestrator notifications. Leave unchanged (smtp.office365.com) if not in-use. | `smtp.office365.com`  |
| `mail.port`        | Port of the above SMTP server. Leave unchanged (587) even if not in-use.                                            | `587`                 |
| `mail.username`    | Username to connect to the above SMTP server.                                                                       | `example@outlook.com` |
| `mail.passwordKey` | Key of the password for the mail authentication, found in `.global.credSecret`.                                     | `mail-password`       |

## More Info

See the main SENSE repo [here](https://github.com/esnet/StackV).
