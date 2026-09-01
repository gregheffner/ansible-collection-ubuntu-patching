# Changelog

## 2.0.0 (2026-08-31)

Ground-up rebuild. Replaces the 1.x collection entirely.

- Two roles: `patch_common` (apt + snap + brew upgrade & cleanup, guarded
  `brew autoremove` via `brew_protected_formulae`) and `k8s_rolling_update`
  (serial drain / reboot / wait-Ready / uncordon, consumed via `tasks_from`).
- All site-specific values (hostnames, users, monitor tooling) removed; the
  1.x Datadog monitor pause/unpause and pod-restart-reset tasks are gone.
- Control host and kubeconfig derived from inventory conventions, overridable.
- Requires ansible-core >= 2.15.
