# Changelog

This file documents all notable changes to StackV's standalone Portal Helm Chart. The release numbering
uses [semantic versioning](http://semver.org).

## 0.1.0

- Initial release. Deploys the standalone SENSE Portal image (`quay.io/virnao/sense-portal`) as a single-replica
  Deployment with a Service and Ingress.
- The proxy allowlist (`ALLOWED_ORIGINS`) is always set from `portal.origin` and `proxy.allowedOrigins`, unless
  `proxy.unrestricted` is enabled.
- The container runs as a non-root user with a read-only root filesystem and no service account token.
