# Ansible Collection - Smart All-Roles System Maintenance

This Ansible collection provides intelligent, comprehensive system maintenance using smart conditional role targeting. Execute all roles together with automatic host group detection for complete infrastructure maintenance.

## Overview

The `gregheffner.ubuntu_patching` collection features Smart Conditional Targeting that automatically runs the appropriate roles based on host group membership. This approach is designed for complete infrastructure maintenance with a single playbook execution.

### Key Features

- **Smart Conditional Targeting**: Automatically runs appropriate roles on correct host groups
- **Complete System Maintenance**: K8s cluster maintenance and Ubuntu system updates
- **Safety-First Design**: K8s maintenance runs first, serial execution prevents issues
- **Docker Integration**: Automatic container management and restarts
- **Datadog Integration**: Monitor pausing and unpausing during maintenance
- **Single Playbook**: Manage entire infrastructure with one command

## Quick Start

```bash
# Install the collection
ansible-galaxy collection install gregheffner.ubuntu_patching

# Run smart all-roles maintenance on your entire infrastructure
ansible-playbook -i inventory.ini smart_all_roles.yml

# Target specific groups (monthly docker updates, K8s maintenance, etc.)
ansible-playbook -i inventory.ini smart_all_roles.yml --limit docker
```

## How Smart Targeting Works

The collection automatically determines which roles run on which hosts:

| Host Group | K8s Maintenance | Ubuntu Update | Use Case |
|------------|----------------|---------------|-----------|
| `k8s_cluster` | **YES** | No | K8s cluster maintenance only |
| `docker` | No | **YES** | Monthly system updates for docker hosts |
| Non-Ubuntu | No | No | Automatically skipped |

## Included Roles

### k8_maintenance

- **Purpose**: Safe Kubernetes cluster maintenance with zero-downtime
- **Features**: Node draining, system updates, monitor management, health checks
- **Auto-runs on**: Hosts in `k8s_cluster` group
- **Integrations**: Datadog monitor pausing, kubectl workflows

### ubuntu_update

- **Purpose**: Comprehensive Ubuntu system updates and maintenance
- **Features**: APT updates, Docker management, package cleanup, optional reboots
- **Auto-runs on**: All Ubuntu systems (detected automatically)
- **Integrations**: Docker container restarts, distribution upgrades

## Installation

```bash
# From Ansible Galaxy (recommended)
ansible-galaxy collection install gregheffner.ubuntu_patching

# From source
git clone https://github.com/gregheffner/ansible-collection-ubuntu-patching.git
cd ansible-collection-ubuntu-patching
ansible-galaxy collection install .
```

## Basic All-Roles Playbook (Smart Conditional)

This playbook automatically runs the appropriate roles based on host group membership:

```yaml
---
- name: Run All Roles from ubuntu_patching Collection
  hosts: all
  become: true
  serial: 1  # For safety, especially with K8s nodes
  vars:
    # Common variables for all roles
    perform_reboot: true
    update_docker: true
    pause_monitors_enabled: true
  roles:
    # K8s maintenance only runs on hosts in k8s_cluster group
    - role: gregheffner.ubuntu_patching.k8_maintenance
      when: "'k8s_cluster' in group_names"
      
    # Ubuntu update runs only on docker hosts
    - role: gregheffner.ubuntu_patching.ubuntu_update
      when: "'docker' in group_names"
```

**Key Benefits:**
- **Automatic targeting** - roles run only on appropriate hosts
- **Single playbook** - manages entire infrastructure  
- **Safe execution** - K8s maintenance runs first, Ubuntu updates last
- **No manual host selection** - uses inventory group membership

## Complete All-Roles Playbook with Full Configuration

```yaml
---
- name: Complete System Maintenance - All Collection Roles
  hosts: all
  become: true
  serial: 1  # Process one host at a time for safety
  gather_facts: true
  
  vars:
    # === Ubuntu Update Role Variables ===
    # Docker settings
    update_docker: true
    restart_docker_containers: true
    
    # Package update settings
    update_packages: true
    update_apt_packages: true
    perform_dist_upgrade: false  # Conservative for automated runs
    cleanup_packages: true
    
    # Reboot settings
    perform_reboot: true
    force_reboot: false
    reboot_method: "modern"
    reboot_timeout: 600
    connect_timeout: 20
    
    # === K8s Maintenance Role Variables ===
    # Datadog monitoring settings
    pause_monitors_enabled: true
    pause_duration: 3600  # 1 hour
    
    # Kubernetes settings
    k8_primary_node: "{{ groups['k8s_cluster'][0] if 'k8s_cluster' in groups else inventory_hostname }}"
    reboot_delay: 30
    reboot_timeout: 600
    node_ready_retries: 30
    node_ready_delay: 10
    
    # Logging settings
    update_log_path: "/mnt/QNAP/backuplogs/updates/updates.txt"

  pre_tasks:
    - name: Display maintenance start time
      debug:
        msg: "Starting complete maintenance on {{ inventory_hostname }} at {{ ansible_date_time.iso8601 }}"
    
    - name: Verify system compatibility
      fail:
        msg: "This collection only supports Ubuntu systems"
      when: ansible_distribution != "Ubuntu"
    
    - name: Create maintenance log entry
      lineinfile:
        path: "{{ update_log_path | default('/tmp/maintenance.log') }}"
        line: "{{ ansible_date_time.iso8601 }} - Starting maintenance on {{ inventory_hostname }}"
        create: true
      delegate_to: localhost
      run_once: true

  roles:
    - role: gregheffner.ubuntu_patching.k8_maintenance
      tags: ['k8s_maintenance', 'kubernetes']
      when: "'k8s_cluster' in group_names"
      
    - role: gregheffner.ubuntu_patching.ubuntu_update
      tags: ['ubuntu_update', 'system_packages']
      when: "ansible_distribution == 'Ubuntu'"

  post_tasks:
    - name: Verify system responsiveness
      ping:
      
    - name: Check for failed services
      shell: systemctl --failed --no-pager
      register: failed_services
      changed_when: false
      failed_when: false
      
    - name: Report any failed services
      debug:
        msg: "WARNING: Failed services found: {{ failed_services.stdout }}"
      when: failed_services.stdout | length > 0
      
    - name: Display maintenance completion
      debug:
        msg: "Maintenance completed successfully on {{ inventory_hostname }} at {{ ansible_date_time.iso8601 }}"
    
    - name: Log maintenance completion
      lineinfile:
        path: "{{ update_log_path | default('/tmp/maintenance.log') }}"
        line: "{{ ansible_date_time.iso8601 }} - Completed maintenance on {{ inventory_hostname }}"
      delegate_to: localhost
```

## Inventory Configuration for Smart All-Roles Execution

```ini
# inventory.ini - Organized for smart conditional targeting

[k8s_cluster]
k8s-master-01.example.com
k8s-worker-01.example.com
k8s-worker-02.example.com
k8s-worker-03.example.com

[docker]
dockerhost ansible_host=localhost

# Smart targeting automatically determines which roles run where:
# - k8s_cluster hosts: Get ONLY k8_maintenance
# - docker hosts: Get ONLY ubuntu_update (perfect for monthly updates)
# - Any non-Ubuntu hosts: Get NO roles (automatically skipped)

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/infrastructure_key
ansible_become=true
ansible_python_interpreter=/usr/bin/python3

# K8s-specific overrides
[k8s_cluster:vars]
pause_monitors_enabled=true
pause_duration=7200  # 2 hours for K8s maintenance
update_log_path=/tmp/k8s_updates.log

# Docker host settings (localhost)
[docker:vars]
perform_dist_upgrade=false
cleanup_packages=true
pause_monitors_enabled=false
update_docker=true
restart_docker_containers=true
```

## Real-World Usage Examples

### Complete Infrastructure Maintenance
```bash
# Smart targeting runs appropriate roles automatically across all hosts
ansible-playbook -i inventory.ini smart_all_roles.yml
```

### Monthly Docker Host Updates  
```bash
# Target just your localhost docker environment for monthly maintenance
ansible-playbook -i inventory.ini smart_all_roles.yml --limit docker
```

### Quick Testing & Validation
```bash
# Dry run to see what would happen without making changes
ansible-playbook -i inventory.ini smart_all_roles.yml --check --diff

# Test on just the docker host first
ansible-playbook -i inventory.ini smart_all_roles.yml --limit docker

# Test on just the K8s cluster
ansible-playbook -i inventory.ini smart_all_roles.yml --limit k8s_cluster
```

### Selective Role Execution
```bash
# Only Ubuntu updates (skip K8s maintenance)
ansible-playbook -i inventory.ini smart_all_roles.yml --tags ubuntu_update

# Only K8s maintenance (skip Ubuntu updates)
ansible-playbook -i inventory.ini smart_all_roles.yml --tags k8s_maintenance
```

### Production Safety Mode
```bash
# Conservative mode - no reboots, no distribution upgrades
ansible-playbook -i inventory.ini smart_all_roles.yml \
  --extra-vars "perform_reboot=false perform_dist_upgrade=false"
```

### 6. Target Specific Host Groups
```bash
# Only K8s cluster
ansible-playbook -i inventory.ini smart_all_roles.yml --limit k8s_cluster

# Only docker hosts
ansible-playbook -i inventory.ini smart_all_roles.yml --limit docker
```

## Variable Precedence and Customization

When running all roles together, variables can be set at multiple levels:

### 1. Playbook Level (Highest Priority)
```yaml
vars:
  perform_reboot: true
  update_docker: true
```

### 2. Group Variables
```yaml
# group_vars/k8s_cluster.yml
pause_monitors_enabled: true
pause_duration: 7200

# group_vars/docker.yml  
perform_dist_upgrade: false
cleanup_packages: false
```

### 3. Host Variables
```yaml
# host_vars/db-01.example.com.yml
perform_reboot: false  # Never auto-reboot database servers
update_docker: false   # No Docker on database servers
```

### 4. Command Line (Highest Priority)
```bash
ansible-playbook smart_all_roles.yml --extra-vars "perform_reboot=false"
```

## Safety Considerations

### Role Execution Order
```yaml
roles:
  - gregheffner.ubuntu_patching.k8_maintenance  # Run first
  - gregheffner.ubuntu_patching.ubuntu_update   # Run last
```
- **Why K8s first**: K8s maintenance completes before any potential Ansible server reboots
- **Why Ubuntu last**: If ubuntu_update reboots the Ansible control node, K8s tasks are already complete
- **Benefit**: Prevents playbook interruption from control node reboots

### Serial Execution
```yaml
serial: 1  # Process one host at a time
```
- **Why**: Prevents simultaneous reboots across infrastructure
- **K8s Benefit**: Ensures only one node is down at a time
- **Alternative**: `serial: 25%` for faster execution with some parallelism

### Conditional Role Execution
```yaml
- role: gregheffner.ubuntu_patching.k8_maintenance
  when: "'k8s_cluster' in group_names"
```
- **Why**: Only applies K8s maintenance to appropriate hosts
- **Benefit**: Prevents errors on non-K8s systems

### Conservative Defaults
```yaml
perform_dist_upgrade: false  # Disable by default
force_reboot: false         # Never force reboot
```

## Monitoring and Logging

### Built-in Logging
```yaml
update_log_path: "/mnt/QNAP/backuplogs/updates/updates.txt"
```

### Custom Log Directory
```bash
# Create logs with timestamp
LOG_DIR="./maintenance_logs/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"

ansible-playbook smart_all_roles.yml | tee "$LOG_DIR/maintenance.log"
```

### Post-Execution Verification
```bash
# Check all systems are responsive
ansible all -i inventory.ini -m ping

# Verify no failed services
ansible all -i inventory.ini -m shell -a "systemctl --failed --no-pager"

# Check K8s cluster health (if applicable)
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running
```

## Troubleshooting

### Common Issues

1. **Role Fails on Non-Ubuntu Systems**
   ```yaml
   pre_tasks:
     - name: Verify Ubuntu
       fail:
         msg: "Only Ubuntu systems supported"
       when: ansible_distribution != "Ubuntu"
   ```

2. **K8s Role Fails on Non-K8s Hosts**
   ```yaml
   - role: gregheffner.ubuntu_patching.k8_maintenance
     when: "'k8s_cluster' in group_names"
   ```

3. **Reboot Timeouts**
   ```yaml
   vars:
     reboot_timeout: 900  # Increase to 15 minutes
     connect_timeout: 30  # Increase connection timeout
   ```

### Recovery Procedures

1. **If a Host Becomes Unresponsive**
   ```bash
   # Check specific host
   ansible target_host -i inventory.ini -m ping
   
   # Manual intervention may be required
   ssh ubuntu@target_host
   ```

2. **If K8s Node Fails to Rejoin**
   ```bash
   # Check node status
   kubectl get nodes
   
   # Manually uncordon if needed
   kubectl uncordon node-name
   ```

## Best Practices

1. **Always Test First**
   ```bash
   ansible-playbook smart_all_roles.yml --check --diff --limit docker
   ```

2. **Use Maintenance Windows**
   - Schedule during low-traffic periods
   - Notify stakeholders beforehand
   - Have rollback procedures ready

3. **Monitor Progress**
   - Use verbose output: `-v`, `-vv`, `-vvv`
   - Monitor logs in real-time
   - Keep backup terminal sessions open

4. **Gradual Rollout**
   ```bash
   # Test on docker host first
   ansible-playbook smart_all_roles.yml --limit docker
   
   # Then K8s cluster
   ansible-playbook smart_all_roles.yml --limit k8s_cluster
   
   # Finally full deployment
   ansible-playbook smart_all_roles.yml
   ```

## Example Maintenance Script

```bash
#!/bin/bash
# complete_maintenance.sh - Run all collection roles safely with smart targeting

set -e

INVENTORY="inventory.ini"
PLAYBOOK="smart_all_roles.yml"  # Smart conditional playbook
LOG_DIR="./maintenance_logs/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$LOG_DIR"

echo "=== Starting Smart All-Roles Maintenance Workflow ==="
echo "Log directory: $LOG_DIR"
echo "Time: $(date)"

# Pre-flight check
echo "=== Pre-flight System Check ==="
ansible all -i "$INVENTORY" -m ping | tee "$LOG_DIR/01_precheck.log"

# Run maintenance with smart targeting
echo "=== Executing All Collection Roles (Smart Conditional) ==="
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" \
  --diff | tee "$LOG_DIR/02_maintenance.log"

# Post-maintenance verification
echo "=== Post-Maintenance Verification ==="
ansible all -i "$INVENTORY" -m ping | tee "$LOG_DIR/03_connectivity.log"
ansible all -i "$INVENTORY" -m shell \
  -a "systemctl --failed --no-pager" | tee "$LOG_DIR/04_services.log"

# K8s cluster check (if applicable)
if kubectl version >/dev/null 2>&1; then
    echo "=== Kubernetes Cluster Health ==="
    {
        echo "=== Nodes ==="
        kubectl get nodes
        echo -e "\n=== Problematic Pods ==="
        kubectl get pods --all-namespaces | grep -v Running | head -10
    } | tee "$LOG_DIR/05_k8s_health.log"
fi

echo "=== Maintenance Complete! ==="
echo "Logs saved to: $LOG_DIR"
echo "Time: $(date)"
```

## Summary

**Smart Conditional All-Roles Collection** provides:

- 🧠 **Intelligent Targeting**: Automatically runs the right roles on the right hosts
- 🔒 **Production Safe**: Serial execution, conservative defaults, safety checks
- **Zero-Downtime K8s**: Proper node draining and health validation
- **Docker Integration**: Container lifecycle management and restarts  
- 📊 **Monitoring Integration**: Datadog monitor management during maintenance
- **Complete Automation**: Single playbook manages entire infrastructure
- **Flexible Execution**: Tag-based filtering, group targeting, variable overrides

### Perfect for:
- **Monthly infrastructure maintenance** across mixed environments
- **Kubernetes cluster patching** with zero downtime
- **Docker host updates** (perfect for localhost environments)
- **Automated maintenance windows** with comprehensive logging
- **Production environments** requiring safety and reliability

This approach eliminates the complexity of managing multiple playbooks while ensuring each host type gets exactly the maintenance it needs.

## License

MIT

## Author Information

Created by [gregheffner](https://github.com/gregheffner) for intelligent, automated Ubuntu system and Kubernetes cluster maintenance.

## Support

- [GitHub Repository](https://github.com/gregheffner/ansible-collection-ubuntu-patching)
- [Issues & Support](https://github.com/gregheffner/ansible-collection-ubuntu-patching/issues)
- [Ansible Galaxy](https://galaxy.ansible.com/gregheffner/ubuntu_patching)

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
  hosts: docker
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