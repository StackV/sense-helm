# SENSE Helm Charts

## Scope

This repository publishes Helm charts for the SENSE Orchestrator platform:

- `orchestrator/`: `sense-orchestrator`, the full SENSE-O application and backing MySQL container.
- `keycloak/`: `sense-keycloak`, wrapping KeycloakX and PostgreSQL.
- `common/`: `sense-commons`, a Helm library chart shared by the application charts.
- `index.yaml`: generated Helm repository index; change it only as part of a chart release.

The main SENSE application repository may be available locally under a directory named `StackV`, or you may need to ask
the user. It is not part of this checkout and may be elsewhere in remote environments. Use it only when the task
explicitly needs application, migration, or image context; do not make this chart repository depend on that path.

## Working Rules

- Preserve the existing chart structure, naming helpers, labels, and values conventions.
- Make the smallest chart and values change that fulfills the request. Do not add compatibility settings without a
  concrete deployment need.
- Treat `values.yaml` as the source of defaults. Update the chart README when a user-facing value, default,
  prerequisite, or deployment behavior changes.
- Never commit credentials, private keys, keystores, database dumps, or site-specific override values. Local overrides
  belong in ignored files such as `override-*.yaml`.
- `kubectl` dry-runs and non-mutating experiments against attached clusters are permitted. Any operation that modifies
  an attached cluster requires explicit user confirmation before execution.
- Do not manually edit generated dependency contents under `**/charts/`, release packages under `.cr-release-packages/`,
  or `index.yaml` outside the release workflow.
- Chart changes require a SemVer bump in that chart's `Chart.yaml`. Update `appVersion` only when the deployed
  application version changes.
- A change to `common/` can affect both application charts. Render and lint each consumer affected by library-template
  changes.

## Helm Workflow

Run commands from the repository root unless a command specifies a chart directory.

1. Check dependencies before linting or rendering a chart that declares them:

   ```sh
   helm dependency build keycloak
   ```

   This populates ignored `charts/` directories from the lockfile. Do not commit the result.

2. Statically validate changed charts:

   ```sh
   helm lint common
   helm lint keycloak
   helm lint orchestrator
   ```

3. Render the affected chart with its defaults and any relevant non-secret override file:

   ```sh
   helm template sense-test orchestrator
   helm template sense-test keycloak
   ```

4. For the orchestrator's integration install, inspect `orchestrator/bin/install.sh` first. It can uninstall a release
   and delete its retained MySQL PVC during a fresh validation run. Use `--dry-run` before cluster mutation; only use
   its default teardown path with an explicit `global.mode: test` override and disposable data.

## Stateful Data and Secrets

- The orchestrator's MySQL PVC is retained on uninstall. Do not delete or reuse a production PVC casually.
- The MySQL 5.7 to 9.7 chart migration requires a fresh PVC and logical dump/restore. Follow `.claude/mysql_migrate.md`;
  do not attempt an in-place image upgrade against an existing data directory.
- Required secret names and keys are documented in each chart README and in `*/bin/create_secrets.sh`. Validate rendered
  `secretKeyRef` values without printing secret contents.

## Release Workflow

- `release.sh <chart-directory>` packages and publishes via the `cr` CLI using `$HOME/.cr.yaml`, pulls from Git, and
  pushes repository artifacts. It mutates and publishes remote state.
- Run releases only when explicitly requested and only from a clean, up-to-date intended branch. Inspect the generated
  package and `index.yaml` before publishing.
- The chart directory arguments currently correspond to local chart directories such as `orchestrator`, `keycloak`, and
  `common`.

## Repository Conventions

- Shell scripts use Bash and should retain `set -euo pipefail` where present.
- Helm templates use two-space YAML indentation and Helm whitespace trimming (`{{-`, `-}}`) consistent with surrounding
  files.
- Kubernetes resource names, namespaces, labels, annotations, image references, and secret keys are deployment API.
  Treat changes to them as compatibility-sensitive and render manifests to review their impact.
- Existing README material may describe legacy releases. Prefer the current `Chart.yaml`, `values.yaml`, templates,
  changelog, and scripts when they conflict.
