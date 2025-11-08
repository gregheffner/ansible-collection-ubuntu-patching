# Kubernetes Cluster Maintenance Role

Automates safe maintenance of Kubernetes clusters with system updates, node reboots, and Datadog monitor management.

## Features

- System updates: APT package updates and distribution upgrades
- Monitor management: Automatic pausing/unpausing of Datadog monitors and synthetic tests  
- Safe node reboots: Proper kubectl drain/uncordon workflow with health checks
- Configurable settings: Customizable timeouts, delays, and monitoring duration
- Activity logging: Comprehensive maintenance activity tracking

## Requirements

- Ansible 2.9+
- kubectl access to the Kubernetes cluster
- 1Password CLI (op) for Datadog API credentials
- Datadog API and Application keys stored in 1Password

## Variables

### Default Variables (defaults/main.yml)

```yaml
# Datadog monitoring settings
pause_monitors_enabled: true
pause_duration: 3600  # 1 hour in seconds

# Kubernetes settings
k8_primary_node: "k8-primary"
reboot_delay: 30
reboot_timeout: 600
node_ready_retries: 30
node_ready_delay: 10

# Logging settings
update_log_path: "/mnt/QNAP/backuplogs/updates/updates.txt"

# Node processing settings
serial_execution: 1  # Process nodes one at a time
```

## Usage

### Basic Usage
```yaml
---
- name: Kubernetes Cluster Maintenance
  hosts: k8s_cluster
  serial: 1
  roles:
    - k8_maintenance
```

### Custom Configuration
```yaml
---
- name: Kubernetes Cluster Maintenance
  hosts: k8s_cluster
  serial: 1
  vars:
    pause_duration: 7200            # Monitor pause duration (seconds)
    k8_primary_node: "master-01"    # Primary node for monitor operations
    reboot_timeout: 900             # Node reboot timeout
    pause_monitors_enabled: false   # Disable monitor management
  roles:
    - k8_maintenance
```

## Workflow

1. **Monitor Pause** (first host only)
   - Retrieve Datadog API credentials from 1Password
   - Pause all Datadog monitors and synthetic tests

2. **Node Maintenance** (all hosts, serial execution)
   - Update APT packages and perform distribution upgrade
   - Truncate nginx logs and log maintenance activity
   - Drain node using kubectl
   - Reboot node and wait for SSH connectivity
   - Wait for node to be Ready in Kubernetes
   - Uncordon the node

3. **Monitor Unpause** (last host only)
   - Unmute all Datadog monitors
   - Resume all synthetic tests

## Prerequisites

### 1Password CLI
Store Datadog credentials in 1Password:
- `op://Secure APIs/vault_dd_api_key/password`
- `op://Secure APIs/vault_dd_app_key/password`

### Inventory Example
```ini
[k8s_cluster]
k8-node-01 ansible_host=192.168.1.101
k8-node-02 ansible_host=192.168.1.102
k8-node-03 ansible_host=192.168.1.103

[k8s_cluster:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/k8s_key
```

## Installation

### From GitHub
```bash
ansible-galaxy install git+https://github.com/gregheffner/ansible-role-k8-maintenance.git
```

### From Requirements File
```yaml
---
roles:
  - src: https://github.com/gregheffner/ansible-role-k8-maintenance.git
    name: k8_maintenance
```

```bash
ansible-galaxy install -r requirements.yml
```

## License

MIT

## Author

gregheffner