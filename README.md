# ubuntu_patching

Weekly, hands-off patching for an Ubuntu fleet. Patches **apt + snap + brew**,
cleans up afterward, and reboots to apply — keeping a Kubernetes cluster live by
doing **one node at a time**.

Published on Galaxy as
[`gregheffner.ubuntu_patching`](https://galaxy.ansible.com/ui/repo/published/gregheffner/ubuntu_patching/),
and also runnable straight from this checkout (that is how the author's own
fleet runs it — see *Run it from a checkout* below).

## Use it as a collection

```bash
ansible-galaxy collection install gregheffner.ubuntu_patching
```

Two roles:

- **`patch_common`** — apt `dist-upgrade` + autoremove/autoclean, `snap refresh`
  + old-revision pruning, and Homebrew/Linuxbrew `update`/`upgrade`/`cleanup`
  run **as the owning user, never root**, with a **guarded `brew autoremove`**:
  list load-bearing formulae in `brew_protected_formulae` and the play fails
  loudly instead of sweeping one that lost its installed-on-request flag.
  Every package manager self-skips when not installed.
- **`k8s_rolling_update`** — the node lifecycle for patching a live cluster:
  `drain` before, `reboot → wait Ready → uncordon` after, all `kubectl` runs
  delegated to the control-plane node. Consumed via `tasks_from` wrapped around
  any patching role, with a `serial: 1` play keeping the cluster available.

```yaml
- name: Patch the cluster one node at a time
  hosts: k8s_cluster
  serial: 1
  become: true
  pre_tasks:
    - ansible.builtin.include_role:
        name: gregheffner.ubuntu_patching.k8s_rolling_update
        tasks_from: drain
  roles:
    - role: gregheffner.ubuntu_patching.patch_common
      vars:
        brew_protected_formulae: [unbound]
  post_tasks:
    - ansible.builtin.include_role:
        name: gregheffner.ubuntu_patching.k8s_rolling_update
        tasks_from: resume
```

Defaults assume the control-plane node is listed **first** in `[k8s_cluster]`
and its `ansible_user` owns the kubeconfig; override `kube_control_host` /
`kubeconfig` if not. All timeouts are variables (see
`roles/k8s_rolling_update/defaults/main.yml`).

## Run it from a checkout

## What runs

`site.yml` has two plays:

| Play | Hosts | What it does |
|------|-------|--------------|
| 1 — cluster | `k8s_cluster` (`serial: 1`) | per node: **drain → patch → truncate nginx logs → reboot → wait Ready → uncordon**. Only advances to the next node once this one is back. |
| 2 — rest | `docker:!k8s_cluster` (= the runner host) | patch, then **always reboot** (scheduled with `shutdown -r +1` so it fires *after* the job exits, since the runner lives here). |

Every patch run **reboots** every host (k8s nodes inline; dockerhost deferred). nginx access/error logs (hostPath from the nginx pods) are truncated on each node before its reboot, so fail2ban doesn't re-ban old 404s when the pod rolls; the task self-skips on hosts without those logs.

The package work is one shared role, [`roles/patch_common`](roles/patch_common/tasks/main.yml):

- **apt** — `update` → `dist-upgrade` → `autoremove --purge` → `autoclean` (with `lock_timeout` to avoid fighting apt-daily)
- **snap** — `snap refresh`, then prune old/disabled revisions
- **brew** — `update && upgrade`, then `autoremove` + `cleanup -s`, **run as the owning login user, never root**

Held packages (`kubelet`, `kubeadm`, `kubectl`, `containerd.io` on the k8s nodes)
are skipped by apt automatically, so the cluster version never moves during a patch.

## Schedule

Dispatched **locally** by a systemd timer on the runner host (Sat 09:47 UTC) via
`gh workflow run`, not by GitHub's cron — GitHub's scheduled triggers proved
unreliable (dropped and late ticks), and a late tick here means draining and
rebooting cluster nodes at the wrong time of day. Trigger manually anytime via
**Actions → Weekly Patching → Run workflow**.

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
ansible-playbook -i inventory/hosts site.yml --limit <node>
```

## Notes / gotchas

- If a node's **drain** can't finish in 300s (e.g. a PodDisruptionBudget blocks
  eviction) the run stops with that node left cordoned — fix the workload and
  re-run with `--limit <node>`, then `kubectl uncordon <node>` if needed.
- Brew running under the CI service account on the runner host is a known
  smell inherited from the existing setup — fine functionally, worth tidying later.
