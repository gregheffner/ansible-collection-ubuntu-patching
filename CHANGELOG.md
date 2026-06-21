# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-06-21

### Added
- **Post-patch pod-restart-reset** step in the `k8_maintenance` role
  (`tasks/pod_restart_reset.yml`). After the cluster is patched, it deletes
  controller-owned **application** pods whose restart count is > 0 so their
  controllers recreate them and `RESTARTS` returns to 0 — a clean post-patch
  health baseline. Runs **once** after the last node is Ready.
  - Cluster services are protected by three independent gates: a namespace
    deny-list, a static/mirror-pod skip (`kubernetes.io/config.mirror`), and a
    controller-owner requirement (ownerReference `controller: true`, kind != Node).
  - Safety: pre-flight node-Ready check, `throttle: 1` with a configurable pause,
    `--wait=false`, dry-run support (`pod_restart_reset_dry_run` / `--check`),
    a post-delete readiness wait, and a loud assertion that restarts are back to 0.
  - New defaults: `pod_restart_reset_enabled`, `pod_restart_reset_dry_run`,
    `pod_restart_reset_delete_pause`, `pod_restart_reset_health_retries`,
    `pod_restart_reset_health_delay`, `pod_restart_reset_exclude_namespaces`.

### Changed
- Raised minimum Ansible to `>=2.15.0` (was `>=2.9.10`).
- `ubuntu_update`: skip the explicit "restart all Docker containers" step when a
  reboot will follow (the reboot restarts them via their restart policy anyway) —
  avoids redundant container churn. Still runs when `perform_reboot: false`.
- `k8_maintenance`: nginx log truncation now skips nodes without nginx (via
  `removes:`) instead of failing, and no longer reports a spurious change.

### Fixed
- README: corrected `pause_monitors_enabled` default (`true`, matching defaults).

## [1.0.0] - 2024-11-08

### Added
- Initial release of gregheffner.ubuntu_patching collection
- `k8_maintenance` role for Kubernetes cluster patching
  - Safe node draining and uncordoning
  - Datadog monitor management during maintenance
  - System updates with proper kubectl workflow
  - Configurable timeouts and retry settings
- `ubuntu_update` role for general Ubuntu system patching
  - APT package updates and optional distribution upgrades
  - Docker container restart capabilities
  - Configurable reboot handling (modern/legacy methods)
  - Post-reboot script execution support
- Example playbooks for different update scenarios
  - Weekly safe updates
  - Monthly comprehensive updates  
  - Docker-only updates
- Comprehensive documentation and usage examples
- Sample inventory configurations

### Features
- Conservative defaults for production safety
- Serial execution for Kubernetes nodes
- Comprehensive logging and error handling
- Datadog integration for monitor management
- Flexible configuration options
- Safety checks and validation

[1.0.0]: https://github.com/gregheffner/ansible-collection-ubuntu-patching/releases/tag/v1.0.0