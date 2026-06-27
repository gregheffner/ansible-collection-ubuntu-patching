# ubuntu-patching

Weekly, hands-off patching for the home-lab Ubuntu fleet. Patches **apt + snap +
brew**, cleans up afterward, and reboots to apply — keeping the Kubernetes
cluster live by doing **one node at a time**.

This replaces the old Galaxy-collection setup. There is **no Galaxy publish step
and no playbook download** — the self-hosted runner checks out this repo and runs
`site.yml` directly, so editing a task and pushing to `main` takes effect on the
very next run.

## What runs

`site.yml` has two plays:

| Play | Hosts | What it does |
|------|-------|--------------|
| 1 — cluster | `k8s_cluster` (`serial: 1`) | per node: **drain → patch → reboot (verified) → wait Ready → uncordon**. Only advances to the next node once this one is back. |
| 2 — rest | `ubuntu:!k8s_cluster` (= `dockerhost`) | patch, then **reboot only if required**, scheduled with `shutdown -r +1` so it fires *after* the job exits (the runner lives here). |

The package work is one shared role, [`roles/patch_common`](roles/patch_common/tasks/main.yml):

- **apt** — `update` → `dist-upgrade` → `autoremove --purge` → `autoclean` (with `lock_timeout` to avoid fighting apt-daily)
- **snap** — `snap refresh`, then prune old/disabled revisions
- **brew** — `update && upgrade`, then `autoremove` + `cleanup -s`, **run as the owning login user, never root**

Held packages (`kubelet`, `kubeadm`, `kubectl`, `containerd.io` on the k8s nodes)
are skipped by apt automatically, so the cluster version never moves during a patch.

## Schedule

GitHub Actions cron (UTC): `0 11 * * 6` → **Saturday ~07:00 Eastern** (06:00 in
winter). Trigger manually anytime via **Actions → Weekly Patching → Run workflow**.

## Inventory

Real inventory is injected at run time from the `ANSIBLE_HOSTS` secret into
`inventory/hosts` (git-ignored). See [`inventory/hosts.example`](inventory/hosts.example)
for the required groups.

## Run it by hand

```bash
# from a checkout on the control node, with a real inventory/hosts:
ansible-playbook -i inventory/hosts site.yml

# dry run / preview:
ansible-playbook -i inventory/hosts site.yml --check --diff

# one host only:
ansible-playbook -i inventory/hosts site.yml --limit worker1
```

## Notes / gotchas

- If a node's **drain** can't finish in 300s (e.g. a PodDisruptionBudget blocks
  eviction) the run stops with that node left cordoned — fix the workload and
  re-run with `--limit <node>`, then `kubectl uncordon <node>` if needed.
- Brew running under the `ansible` service account on dockerhost is a known
  smell inherited from the existing setup — fine functionally, worth tidying later.
