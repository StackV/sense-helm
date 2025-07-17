# Changelog

This file documents all notable changes to StackV's main Orchestrator Helm Chart.
The release numbering uses [semantic versioning](http://semver.org).

## 1.14.0

- **Breaking**: The KC auth secret will need to be updated for this version. For ease of transitioning between KC providers and secret integrity, the `auth.host` value has been moved into the `host` key of the KC auth secret. See `bin/create_secrets.sh` for an example.

## 1.13.0

- Added a `extraObjects` value to allow for generic sideloading of extra K8s manifests, such as external secrets.

## 1.12.0

- **Breaking:** A new secret for Keycloak client authentication is required. See the readme or `./bin/create.secrets.sh` for details.
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
