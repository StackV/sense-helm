# SENSE Portal

This chart installs the standalone SENSE Portal (SENSE-P) on a K8s cluster. The portal is normally served by the
orchestrator at `/StackV-web/portal/`; in standalone mode the same web app runs in its own container, together with a
small proxy that forwards API calls any number of configured SENSE-O deployments. This allows a user to use one portal
to switch between multiple orchestrator deployments in the same page.

## Prerequisites

The chart is stateless and has no database, and so is relatively light on requirements.

### Keycloak client

The portal signs users in via the same Keycloak server used by its target orchestrator. **Before operation, you will
need to add the portal's host to the Portal client**, or Keycloak will refuse the login redirect:

- *Valid redirect URIs*: `https://{{ingress.hostname or global.domain}}/StackV-web/portal/*`
- *Web origins*: `https://{{ingress.hostname or global.domain}}`

Repeat this for the Keycloak servers of any orchestrators the portal intends to connect to.

The Keycloak URL is discovered from the orchestrator's `/restapi/system/info` endpoint. Set `portal.keycloakUrl` only to
override it.

### Secrets

The chart requires no secrets. Set `image.pullSecrets` only if the image registry is private.

## Configuration

In most cases you should be fine reviewing the variables established below from the full `values.yaml` as a base. Copy
this to a new file, `override-<site>.yaml`, and from there you can remove any unneeded fields that you plan on leaving
to their default values.

### Proxy targets

The portal chooses which orchestrator the proxy forwards to with a `Standalone-Target` header, so an unrestricted proxy
forwards requests to any origin a client names. The chart therefore always sets the proxy's `ALLOWED_ORIGINS`
allowlist, built from `portal.origin` plus `proxy.allowedOrigins`:

```yaml
portal:
  origin: https://orch-a.example.net/StackV-web
proxy:
  allowedOrigins:
    - https://orch-b.example.net
```

Entries are compared by origin (scheme, host, port), so paths are ignored. Requests to any other origin receive `403`.
Setting `proxy.unrestricted: true` removes the allowlist entirely. Only do this for a deployment that no one else can
reach.

### TLS

The container serves plain HTTP on port 8887, and TLS is terminated at the Ingress. Provide a certificate through the
usual cert-manager Ingress annotation, for example `cert-manager.io/cluster-issuer`, or through an existing secret named
by `ingress.tlsSecret`. The Ingress only routes `/StackV-web`.

## Installation

After configuring your override, run `helm install senseo-portal . -f override-<site>.yaml`.

## Usage

Once ready, the portal should be accessible via the established ingress at an address similar to
`https://{{ingress.hostname or global.domain}}/StackV-web/portal/`.

If the ingress was disabled or is non-functional, you can access the portal via port-forwarding with a command like
`kubectl port-forward svc/senseo-portal-sense-portal 8887:8887`, which should make it available at
`http://localhost:8887/StackV-web/portal/`. Keycloak will only accept this address if it is also registered on the
`Portal` client.

Other orchestrators can be added from the portal's connection menu, as long as they are in the proxy allowlist.

## Parameters

### Global Parameters

| Name                | Description                            | Value                 |
|---------------------|----------------------------------------|-----------------------|
| `global.nameSuffix` | A name to append to the Release Name.  | `sense`               |
| `global.namespace`  | The target namespace.                  | `sense`               |
| `global.domain`     | The host domain for the portal.        | `portal.sense.es.net` |
| `extraObjects`      | Array of extra K8s manifests to deploy | `[]`                  |

### Portal Parameters

| Name                           | Description                                                                                                                                | Value                                    |
|--------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|
| `image.repository`             | Standalone portal image.                                                                                                                   | `quay.io/virnao/sense-portal`            |
| `image.tag`                    | Image tag to pull. Defaults to the chart's `appVersion` if unset.                                                                          | `dev`                                    |
| `image.pullPolicy`             | Portal image pull policy. Floating tags such as `dev` need `Always` to pick up new builds on restart.                                      | `Always`                                 |
| `image.pullSecrets`            | Secrets for any private docker registry access.                                                                                            | `[]`                                     |
| `portal.origin`                | Orchestrator base URL (including `/StackV-web`) the portal connects to by default.                                                         | `https://stackv.sense.es.net/StackV-web` |
| `portal.defaultDeploymentName` | Label for the default deployment in the portal's connection menu.                                                                          | `Default`                                |
| `portal.keycloakUrl`           | Explicit Keycloak URL. Auto-discovered from the target orchestrator's `/restapi/system/info` if unset.                                     | `nil`                                    |
| `portal.insecureTls`           | If set to `true`, skips upstream orchestrator certificate verification. Development only.                                                  | `false`                                  |
| `proxy.allowedOrigins`         | Additional orchestrator origins the portal proxy may forward to. `portal.origin` is always allowed.                                        | `[]`                                     |
| `proxy.unrestricted`           | If set to `true`, the proxy forwards to any origin a client names. This is an open forward proxy; do not enable on a reachable deployment. | `false`                                  |
| `resources.requests.cpu`       | Portal CPU request.                                                                                                                        | `100m`                                   |
| `resources.requests.memory`    | Portal memory request.                                                                                                                     | `128Mi`                                  |
| `resources.limits.cpu`         | Portal CPU limit.                                                                                                                          | `500m`                                   |
| `resources.limits.memory`      | Portal memory limit.                                                                                                                       | `512Mi`                                  |
| `service.type`                 | Portal service type.                                                                                                                       | `ClusterIP`                              |
| `service.ports.http`           | Portal HTTP port.                                                                                                                          | `8887`                                   |
| `probes.startup.enabled`       | Whether to enable the default Portal startup probe.                                                                                        | `true`                                   |
| `probes.startup.custom`        | A custom override for the Portal startup probe.                                                                                            | `{}`                                     |
| `probes.liveness.enabled`      | Whether to enable the default Portal liveness probe.                                                                                       | `true`                                   |
| `probes.liveness.custom`       | A custom override for the Portal liveness probe.                                                                                           | `{}`                                     |
| `probes.readiness.enabled`     | Whether to enable the default Portal readiness probe.                                                                                      | `true`                                   |
| `probes.readiness.custom`      | A custom override for the Portal readiness probe.                                                                                          | `{}`                                     |
| `nodeSelector`                 | Portal nodeSelector block.                                                                                                                 | `{}`                                     |
| `tolerations`                  | Portal tolerations block.                                                                                                                  | `[]`                                     |
| `affinity`                     | Portal affinity block.                                                                                                                     | `{}`                                     |

### Network Parameters

| Name                  | Description                                                                                  | Value  |
|-----------------------|----------------------------------------------------------------------------------------------|--------|
| `ingress.enabled`     | Whether to enable the Ingress resource.                                                      | `true` |
| `ingress.className`   | Ingress class override. Defaults to the cluster's default ingress class if unset.            | `nil`  |
| `ingress.hostname`    | Explicit host to be used for the ingress. Defaults to the value of `global.domain` if unset. | `nil`  |
| `ingress.annotations` | Any optional annotations for the Ingress, such as a cert-manager issuer.                     | `nil`  |
| `ingress.tlsSecret`   | TLS secret name for ingress termination.                                                     | `nil`  |

## More Info

See the main SENSE repo [here](https://github.com/esnet/StackV).
