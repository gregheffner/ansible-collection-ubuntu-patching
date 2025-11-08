# Ansible Collection - gregheffner.ubuntu_patching

This Ansible collection provides comprehensive Ubuntu system patching and maintenance capabilities, including Kubernetes cluster maintenance and automated server patching workflows.

## Features

- **K8s Patching**: Safe Kubernetes cluster patching with node draining, system updates, and monitoring management
- **System Patching**: Comprehensive Ubuntu system updates with Docker support and optional reboots
- **Datadog Integration**: Automatic monitor pausing/unpausing during maintenance windows
- **Safety Features**: Conservative defaults and proper error handling for production environments

## Included Roles

### 1. k8_maintenance

Automates safe maintenance of Kubernetes clusters with system updates, node reboots, and Datadog monitor management.

**Features:**
- System updates: APT package updates and distribution upgrades
- Monitor management: Automatic pausing/unpausing of Datadog monitors and synthetic tests  
- Safe node reboots: Proper kubectl drain/uncordon workflow with health checks
- Configurable settings: Customizable timeouts, delays, and monitoring duration
- Activity logging: Comprehensive maintenance activity tracking

**Requirements:**
- Ansible 2.9+
- kubectl access to the Kubernetes cluster
- 1Password CLI (op) for Datadog API credentials
- Datadog API and Application keys stored in 1Password

### 2. ubuntu_update

Handles comprehensive system updates for Ubuntu systems, including Docker container management and optional reboot functionality.

**Features:**
- Docker Management: Restart all Docker containers to pick up latest configurations
- Package Updates: APT packages for Ubuntu systems with safe weekly vs comprehensive monthly updates
- System Maintenance: Package cleanup and optional distribution upgrades  
- Reboot Support: Optional system reboot with configurable timeouts
- Post-Reboot Scripts: Run custom scripts after reboot (optional)

**Requirements:**
- Ansible 2.9+
- Ubuntu system (role will fail on non-Ubuntu systems)
- Appropriate privileges for package management (sudo/become)
- Docker (optional, for Docker-related tasks)

## Installation

### From Ansible Galaxy (Recommended)

```bash
# Install the collection
ansible-galaxy collection install gregheffner.ubuntu_patching

# Or add to requirements.yml
collections:
  - name: gregheffner.ubuntu_patching
    version: ">=1.0.0"
```

### From Source

```bash
# Clone and install from source
git clone https://github.com/gregheffner/ansible-collection-ubuntu-patching.git
cd ansible-collection-ubuntu-patching
ansible-galaxy collection install .
```

## Quick Start

### Kubernetes Cluster Maintenance

```yaml
---
- name: Kubernetes Cluster Maintenance
  hosts: k8s_cluster
  serial: 1
  roles:
    - gregheffner.ubuntu_patching.k8_maintenance
```

### Ubuntu System Updates

```yaml
---
- name: Weekly Safe Updates
  hosts: ubuntu_servers
  become: true
  vars:
    perform_dist_upgrade: false        # Safe for automation
    perform_reboot: true              # Reboot after updates
    update_docker: true               # Restart Docker containers
  roles:
    - gregheffner.ubuntu_patching.ubuntu_update
```

## Example Playbooks

### 1. Complete K8s Cluster Maintenance

```yaml
---
- name: Kubernetes Cluster Maintenance with Custom Settings
  hosts: k8s_cluster
  serial: 1
  vars:
    pause_duration: 7200            # Monitor pause duration (seconds)
    k8_primary_node: "master-01"    # Primary node for monitor operations
    reboot_timeout: 900             # Node reboot timeout
    pause_monitors_enabled: true    # Enable monitor management
  roles:
    - gregheffner.ubuntu_patching.k8_maintenance
```

### 2. Monthly Comprehensive Updates

```yaml
---
- name: Monthly Comprehensive System Updates
  hosts: ubuntu_servers
  become: true
  vars:
    perform_dist_upgrade: true        # More comprehensive
    perform_reboot: true
    update_docker: true
    cleanup_packages: true
  roles:
    - gregheffner.ubuntu_patching.ubuntu_update
```

### 3. Docker-only Updates

```yaml
---
- name: Docker Container Restart Only
  hosts: docker_hosts
  vars:
    update_packages: false            # Skip system packages
    perform_reboot: false            # No reboot needed
    update_docker: true              # Only restart Docker
  roles:
    - gregheffner.ubuntu_patching.ubuntu_update
```

## Configuration

### K8s Maintenance Variables

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
```

### Ubuntu Update Variables

```yaml
# Docker settings
update_docker: true
restart_docker_containers: true

# Package update settings
update_packages: true
update_apt_packages: true
perform_dist_upgrade: false           # Disabled by default for safety
cleanup_packages: true

# Reboot settings
perform_reboot: true
force_reboot: false
reboot_method: "modern"              # "modern" or "legacy"
reboot_timeout: 600
connect_timeout: 20
```

## Prerequisites

### For K8s Maintenance

1. **1Password CLI Setup**
   Store Datadog credentials in 1Password:
   - `op://Secure APIs/vault_dd_api_key/password`
   - `op://Secure APIs/vault_dd_app_key/password`

2. **Inventory Example**
   ```ini
   [k8s_cluster]
   k8-node-01 ansible_host=192.168.1.101
   k8-node-02 ansible_host=192.168.1.102
   k8-node-03 ansible_host=192.168.1.103

   [k8s_cluster:vars]
   ansible_user=ubuntu
   ansible_ssh_private_key_file=~/.ssh/k8s_key
   ```

## Safety Features

- **Conservative Defaults**: Distribution upgrades disabled by default
- **Flexible Reboots**: Choose between modern (reboot module) or legacy methods
- **Fail-Safe**: Continue on errors for non-critical tasks
- **Detailed Reporting**: Shows what was updated and restart status
- **Serial Execution**: K8s maintenance processes nodes one at a time

## License

MIT

## Author Information

Created by [gregheffner](https://github.com/gregheffner) for automated Ubuntu system and Kubernetes cluster maintenance.

## Support

- [GitHub Issues](https://github.com/gregheffner/ansible-collection-ubuntu-patching/issues)
- [Documentation](https://github.com/gregheffner/ansible-collection-ubuntu-patching)