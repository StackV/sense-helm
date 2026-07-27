# Changelog

This file documents all notable changes to StackV's main Orchestrator Helm Chart. The release numbering
uses [semantic versioning](http://semver.org).

## 2.0.0

- **Breaking:** Upgrade the bundled MySQL server from 5.7 to 9.7 (LTS). Dump and reload onto a fresh volume if required;
  see the migration steps in `../.claude/mysql_migrate.md`. The existing PVC remains due and is retained as a rollback.
- **Breaking:** Replace Sqitch with Flyway for database migrations.
- **Breaking:** Drop the separate `frontend` migration init container. The `frontend` schema is now self-provisioned by
  the application at boot, so only the `rainsdb` migration container remains.
- The MySQL image is now configurable via `mysql.image.repository`, `mysql.image.tag` and `mysql.image.pullPolicy`.
- Fix the MySQL startup probe.
- Extend the MySQL liveness and readiness probes.
- MySQL probes no longer pass the root password on the command line, where it was visible in the container's process
  table.
- Add `mysql.terminationGracePeriodSeconds` (default 120) so InnoDB can shut down cleanly instead of forcing crash
  recovery on the next start.
- Add a `checksum/config` annotation to the MySQL pod, so changes to `db.cnf` actually roll the StatefulSet.
- Add `mysql.binlog.*`. Binary logging is on by default from MySQL 8.0; on a single non-replicated node it only consumes
  volume space, so it is disabled by default here.
- Add `mysql.pvcSize`, previously erroneously hardcoded.
- Fix `ingress.tlsSecret` name being ignored.
- Fix `service.ports.debug.consoleHttp`, `consoleHttps` and `debugger` ports being ignored.
- Fix Ingress backend port so it follows `service.ports.http` instead of hardcoded.
- Add `init.migration.connectRetries` (default 60) so the migration container waits out MySQL's first boot rather than
  relying on init container restarts.

## 1.15.0

- Fix default mysql liveness probe definition.
- Establish tested baseline.

## 1.14.11

- Fix bug with Argo type destructuring.

## 1.14.10

- Fix bug with specifying custom PVC storage class.

## 1.14.8

- Clean up README, point to new documentation site.
- Specify default values for more values fields.

## 1.14.7

- Assorted stateful set fixes.
- Set readiness probe defaults to use HTTP heartbeat endpoint instead.

## 1.14.4

- Extend default liveness threshold to accomodate standard container delays.

## 1.14.3

- Converted orchestrator Deployment to Statefulset in order to get around pruning policies at IRI.

## 1.14.2

- Added built-in templating support for generic certmanager certificate requests.
- Fixed minor configuration issues for the deployment and ingress resources.

## 1.14.0

- **Breaking**: The KC auth secret will need to be updated for this version. For ease of transitioning between KC
  providers and secret integrity, the `auth.host` value has been moved into the `host` key of the KC auth secret. See
  `bin/create_secrets.sh` for an example.

## 1.13.0

- Added a `extraObjects` value to allow for generic sideloading of extra K8s manifests, such as external secrets.

## 1.12.0

- **Breaking:** A new secret for Keycloak client authentication is required. See the readme or `./bin/create.secrets.sh`
  for details.
- New orchestrator configuration to adapt to updated Keycloak variations.

## 1.11.1

Passthrough JVM memory maximum allocation setting.

## 1.11.0

Make DB migration specification more intuitive and consistent. Add default blank keystore secret.

## 1.10.1

Allow better Issuer configuration.

## 1.10.0

Add new DB migration functionality, remove built-in SQL data dumps.

## 1.9.8

Standardize name templating.

## 1.9.7

Fix service bug with selectors.

## 1.9.5

Add more appropriate defaulting, as well as common labels.

## 1.9.4

Standardize probe templating. Add basic common functions.

## 1.9.3

Fix missing PVC override.

## 1.9.2

Minor fixes for sane defaulting.

## 1.9.1

Minor fixes for port syntax and naming.

## 1.9.0

Second pass over templating for best practices.

## 1.8.0

Refactor configuration, and clean up documentation.

## 1.7.4

Update secret value naming.

## 1.7.3

Update ingress default definition.
