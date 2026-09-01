# k8s_rolling_update

Node lifecycle for patching a live Kubernetes cluster one node at a time:
**drain** before your patching work, **reboot / wait Ready / uncordon** after.
All `kubectl` commands are delegated to the control-plane node.

Consumed via `tasks_from`, wrapped around any patching role, in a `serial: 1`
play (see the collection README for a full example):

```yaml
pre_tasks:
  - ansible.builtin.include_role:
      name: gregheffner.ubuntu_patching.k8s_rolling_update
      tasks_from: drain
roles:
  - role: gregheffner.ubuntu_patching.patch_common
post_tasks:
  - ansible.builtin.include_role:
      name: gregheffner.ubuntu_patching.k8s_rolling_update
      tasks_from: resume
```

Running the role bare executes drain then resume — a rolling reboot.

## Variables (defaults/main.yml)

| Variable | Default | Purpose |
|---|---|---|
| `kube_control_host` | first host in `[k8s_cluster]` | Where kubectl runs |
| `kubeconfig` | `/home/<its ansible_user>/.kube/config` | Kubeconfig path |
| `drain_timeout` | `300` | kubectl drain timeout (s) |
| `reboot_timeout` / `post_reboot_delay` | `900` / `30` | Reboot handling (s) |
| `ready_wait_timeout` / `ready_retries` / `ready_delay` | `300` / `20` / `15` | Wait-Ready loop |
