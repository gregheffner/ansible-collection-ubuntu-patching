# Ansible Collection - Automated Infrastructure Patching

[![Ansible Galaxy](https://img.shields.io/badge/galaxy-gregheffner.ubuntu__patching-blue.svg)](https://galaxy.ansible.com/gregheffner/ubuntu_patching)

## What This Does

This Ansible collection **automates complete infrastructure maintenance** for Ubuntu-based Kubernetes clusters and Docker hosts. It handles system updates, Kubernetes node maintenance, Docker updates, and automated reboots—all with proper sequencing to prevent downtime.

**Perfect for:**
- Homelab Kubernetes clusters that need regular patching
- Small production K8s environments
- Automated weekly maintenance via GitHub Actions
- Docker hosts that need coordinated updates

## How It Works

### 🔄 Automated Workflow

1. **GitHub Actions triggers** weekly maintenance (or manual runs)
2. **Updates Ansible collection** from Galaxy automatically
3. **Phase 1: K8s Cluster** - Updates all nodes sequentially:
   - Pauses Datadog monitors (optional)
   - Drains node from cluster
   - Updates system packages
   - Reboots node
   - Waits for node to rejoin cluster
   - Uncordons node
   - Moves to next node
   - **After all nodes are Ready:** resets application pod restart counters
     (deletes app pods with `RESTARTS > 0` so controllers recreate them clean;
     cluster services are never touched)
4. **Phase 2: Docker Host** - After K8s is complete:
   - Updates system packages
   - Updates Docker
   - Reboots host
5. **Resumes Datadog monitors**
6. **Generates detailed summary** in GitHub Actions UI

### 📦 What's Included

#### Two Ansible Roles:

**`k8_maintenance`** - Kubernetes cluster maintenance
- Node draining and uncordoning
- System package updates
- Automated reboots with cluster health checks
- Datadog monitor pause/unpause
- Nginx log truncation
- Post-patch pod-restart-reset (resets `RESTARTS` to 0 on application pods, excludes cluster services)

**`ubuntu_update`** - Ubuntu system updates
- APT package updates and upgrades
- Docker updates
- Package cleanup
- Fire-and-forget reboots

#### Three Ready-to-Use Playbooks:

- **`sequential_maintenance.yml`** - Complete infrastructure (K8s → Docker host)
- **`smart_all_roles.yml`** - Run all roles with smart targeting
- **`inventory.example`** - Sample inventory setup

#### Three GitHub Actions Workflows:

- **Weekly Maintenance** - Full infrastructure, runs every Saturday
- **K8s Maintenance Only** - Manual trigger for K8s cluster only
- **Ubuntu Updates Only** - Manual trigger for system updates only

## Quick Start

### 1. Install the Collection

```bash
ansible-galaxy collection install gregheffner.ubuntu_patching
```

### 2. Set Up Your Inventory

Create `hosts.ini`:

```ini
[k8s_cluster]
k8-primary ansible_host=192.168.1.10
worker1 ansible_host=192.168.1.11
worker2 ansible_host=192.168.1.12

[dockerhost]
dockerhost ansible_host=192.168.1.20

[all:vars]
ansible_user=your_user
ansible_become=true
```

### 3. Run Maintenance

```bash
# Complete sequential maintenance (recommended)
ansible-playbook sequential_maintenance.yml -i hosts.ini

# K8s cluster only
ansible-playbook smart_all_roles.yml -i hosts.ini --tags k8s_maintenance

# Ubuntu updates only  
ansible-playbook smart_all_roles.yml -i hosts.ini --tags ubuntu_update
```

## Installation Methods

### From Ansible Galaxy (Recommended)

```bash
ansible-galaxy collection install gregheffner.ubuntu_patching
```

### From Source

```bash
git clone https://github.com/gregheffner/ansible-collection-ubuntu-patching.git
cd ansible-collection-ubuntu-patching
ansible-galaxy collection install .
```

## Playbook Options

### Sequential Execution Flow

```
┌─────────────────────────────────────┐
│  GitHub Actions Trigger             │
│  (Weekly or Manual)                 │
└───────────┬─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  Update Collection from Galaxy      │
└───────────┬─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  Phase 1: K8s Cluster               │
│  ├─ Pause Datadog monitors          │
│  ├─ For each node (serial):         │
│  │  ├─ Drain node                   │
│  │  ├─ Update packages               │
│  │  ├─ Reboot                        │
│  │  ├─ Wait for ready                │
│  │  └─ Uncordon node                 │
│  ├─ All nodes complete               │
│  └─ Reset app pod restart counters   │
│     (excludes cluster services)      │
└───────────┬─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  Phase 2: Docker Host               │
│  ├─ Fix /tmp permissions            │
│  ├─ Update packages                 │
│  ├─ Update Docker                   │
│  └─ Reboot                           │
└───────────┬─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  Resume Datadog monitors            │
└───────────┬─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  Generate Summary Report            │
└─────────────────────────────────────┘
```

### Why This Order?

1. **K8s nodes first** - Ensures cluster is fully updated and stable
2. **Docker host last** - This is often the Ansible controller; updating it last prevents connection loss during K8s operations
3. **Serial execution** - One node at a time maintains cluster availability
4. **Health checks** - Each node must rejoin cluster before moving to next


## Configuration Variables

### K8s Maintenance Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `pause_monitors_enabled` | `true` | Pause Datadog monitors during maintenance |
| `pause_duration` | `3600` | How long to pause monitors (seconds) |
| `k8_primary_node` | First node | K8s primary node for kubectl commands |
| `reboot_delay` | `30` | Wait time before reboot (seconds) |
| `node_ready_retries` | `30` | How many times to check node status |
| `node_ready_delay` | `10` | Seconds between node status checks |
| `pod_restart_reset_enabled` | `true` | Reset app pod restart counters after patching |
| `pod_restart_reset_dry_run` | `false` | Preview only (`kubectl --dry-run=server`); also honored by `--check` |
| `pod_restart_reset_delete_pause` | `5` | Seconds between pod deletions (anti-thundering-herd) |
| `pod_restart_reset_health_retries` | `30` | Post-delete: times to wait for recreated pods to be Ready |
| `pod_restart_reset_health_delay` | `10` | Seconds between readiness checks |
| `pod_restart_reset_exclude_namespaces` | see defaults | Cluster-service namespaces never touched |

#### Post-patch pod-restart-reset

After every node is patched and `Ready`, the role deletes **only** controller-owned
**application** pods whose restart count is `> 0`, so their controllers recreate
them and `RESTARTS` returns to 0. A pod is deleted only if it clears **all three**
gates: (1) not in `pod_restart_reset_exclude_namespaces`, (2) not a static/mirror
pod (`kubernetes.io/config.mirror`), and (3) owned by a controller (`controller:
true`, kind != `Node`). Control-plane static pods (etcd, apiserver, scheduler,
controller-manager) are therefore never selected. Deletions are throttled one at a
time, then the step waits for recreated pods to become Ready and asserts restarts
are back to 0. Set `pod_restart_reset_dry_run: true` (or run with `--check`) to
preview the kill list without deleting anything.

### Ubuntu Update Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `perform_reboot` | `true` | Reboot after updates |
| `update_docker` | `false` | Update Docker packages |
| `update_packages` | `true` | Run APT updates |
| `cleanup_packages` | `true` | Remove unused packages |
| `reboot_timeout` | `600` | Max seconds to wait for reboot |

## Summary

**Sequential Infrastructure Maintenance Collection** provides:

- **Sequential Phase Execution**: K8s cluster maintenance completes before docker host updates
- **Production Safety**: Control nodes never interrupted during K8s operations  
- **Intelligent Targeting**: Automatically runs the right roles on the right hosts
- **Zero-Downtime K8s**: Proper node draining and health validation
- **Docker Integration**: Container lifecycle management and restarts  
- **Monitoring Integration**: Datadog monitor management during maintenance
- **Complete Automation**: Single playbook manages entire infrastructure with proper sequencing
- **Flexible Execution**: Break out phases when needed, tag-based filtering, group targeting

### Perfect for:

- **Production infrastructure maintenance** requiring safe execution order
- **Monthly infrastructure maintenance** across mixed K8s and standalone environments
- **Kubernetes cluster patching** with zero downtime
- **Docker host updates** (perfect for localhost environments)
- **Automated maintenance windows** with comprehensive logging
- **Production environments** requiring safety and reliability

### Key Playbooks:

- **`sequential_maintenance.yml`** - Primary recommended playbook (K8s first, then docker)
- **`smart_all_roles.yml`** - Smart conditional targeting (use with --limit for individual phases)
- **Docker host updates** (perfect for localhost environments)
- **Automated maintenance windows** with comprehensive logging
- **Production environments** requiring safety and reliability

This approach eliminates the complexity of managing multiple playbooks while ensuring each host type gets exactly the maintenance it needs.
