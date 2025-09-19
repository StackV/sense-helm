# Changelog

This file documents all notable changes to StackV's pre-configured Keycloak Helm Chart.
The release numbering uses [semantic versioning](http://semver.org).

## 0.8.0

- Replace deprecated Bitnami postgresql subchart with direct provisioning.

## 0.7.1

- Adjust ingress pathing to match KC 17 API change.

## 0.7.0

- Test new KC version and templating.

## 0.6.5

- Make underlying PostgreSQL persist the PVC.

## 0.6.4

- Update custom ingress and issuer support.

## 0.6.3

- Patch fix for bitnami service naming truncation.

## 0.6.2

- Better templating for Bitnami config patch.

## 0.6.1

- Update Keycloak service away from LoadBalancer by default.

## 0.6.0

- Initial port of legacy chart. Uses a patched version of bitnami's 18.0.2 chart.
