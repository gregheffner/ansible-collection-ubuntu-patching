# patch_common

Upgrade and clean up every package manager present on a host: apt
(`dist-upgrade` + autoremove/autoclean), snap (`refresh` + old-revision
pruning), and Homebrew/Linuxbrew (`update`/`upgrade`/`autoremove`/`cleanup`),
with brew always run as its owning user, never root. Each manager self-skips
when not installed.

The `brew autoremove` step is **guarded**: a dry-run first, and the play fails
loudly if any formula in `brew_protected_formulae` would be swept (a formula
that lost its installed-on-request flag). Re-flag with `brew install <formula>`
and re-run.

## Variables (defaults/main.yml)

| Variable | Default | Purpose |
|---|---|---|
| `patch_apt` / `patch_snap` / `patch_brew` | `true` | Toggle each manager |
| `brew_bin` | `/home/linuxbrew/.linuxbrew/bin/brew` | Brew prefix binary |
| `apt_lock_timeout` | `300` | Seconds to wait on the dpkg/apt lock |
| `brew_protected_formulae` | `[unbound]` | Formulae `brew autoremove` must never sweep |
