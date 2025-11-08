# Running All Collection Roles - Complete System Maintenance

This guide focuses on running all roles from the `gregheffner.ubuntu_patching` collection in a single playbook for comprehensive system maintenance.

## Overview

The `gregheffner.ubuntu_patching` collection contains multiple roles that can be executed together to perform complete system maintenance across your infrastructure. This approach is ideal for scheduled maintenance windows where you want to apply all updates and maintenance tasks in one operation.

## Basic All-Roles Playbook

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
    - gregheffner.ubuntu_patching.k8_maintenance
    - gregheffner.ubuntu_patching.ubuntu_update
```

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

## Inventory Configuration for All-Roles Execution

```ini
# inventory.ini - Organized for all-roles execution

[k8s_cluster]
k8s-master-01.example.com k8_primary_node=true
k8s-worker-01.example.com
k8s-worker-02.example.com
k8s-worker-03.example.com

[standard_servers]
web-01.example.com
web-02.example.com
db-01.example.com
app-01.example.com

[docker_hosts]
docker-01.example.com
docker-02.example.com

# All systems will get ubuntu_update, only k8s_cluster gets k8_maintenance
[all:children]
k8s_cluster
standard_servers
docker_hosts

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/infrastructure_key
ansible_become=true
ansible_python_interpreter=/usr/bin/python3

# K8s-specific overrides
[k8s_cluster:vars]
pause_monitors_enabled=true
pause_duration=7200  # 2 hours for K8s maintenance
update_log_path=/mnt/QNAP/backuplogs/updates/k8s_updates.txt

# Conservative settings for database servers
[standard_servers:vars]
perform_dist_upgrade=false
cleanup_packages=false
```

## Usage Examples

### 1. Run All Roles on All Hosts
```bash
ansible-playbook -i inventory.ini all_roles_maintenance.yml
```

### 2. Run with Dry Run (Check Mode)
```bash
ansible-playbook -i inventory.ini all_roles_maintenance.yml --check --diff
```

### 3. Run Only Ubuntu Updates (Skip K8s Maintenance)
```bash
ansible-playbook -i inventory.ini all_roles_maintenance.yml --tags ubuntu_update
```

### 4. Run Only K8s Maintenance (Skip Ubuntu Updates)
```bash
ansible-playbook -i inventory.ini all_roles_maintenance.yml --tags k8s_maintenance
```

**Important**: When running all roles together, K8s maintenance always runs first to prevent playbook interruption if the Ansible control node gets rebooted by ubuntu_update.

### 5. Override Variables at Runtime
```bash
ansible-playbook -i inventory.ini all_roles_maintenance.yml \
  --extra-vars "perform_reboot=false pause_monitors_enabled=false"
```

### 6. Target Specific Host Groups
```bash
# Only K8s cluster
ansible-playbook -i inventory.ini all_roles_maintenance.yml --limit k8s_cluster

# Only standard servers
ansible-playbook -i inventory.ini all_roles_maintenance.yml --limit standard_servers
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

# group_vars/standard_servers.yml  
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
ansible-playbook all_roles_maintenance.yml --extra-vars "perform_reboot=false"
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

ansible-playbook all_roles_maintenance.yml | tee "$LOG_DIR/maintenance.log"
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
   ansible-playbook all_roles_maintenance.yml --check --diff --limit test_host
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
   # Test on one host first
   ansible-playbook all_roles_maintenance.yml --limit test_host
   
   # Then small groups
   ansible-playbook all_roles_maintenance.yml --limit web_servers
   
   # Finally full deployment
   ansible-playbook all_roles_maintenance.yml
   ```

## Example Maintenance Script

```bash
#!/bin/bash
# complete_maintenance.sh - Run all collection roles safely

set -e

INVENTORY="inventory.ini"
PLAYBOOK="all_roles_maintenance.yml"
LOG_DIR="./maintenance_logs/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$LOG_DIR"

echo "=== Starting Complete Maintenance Workflow ==="
echo "Log directory: $LOG_DIR"
echo "Time: $(date)"

# Pre-flight check
echo "=== Pre-flight System Check ==="
ansible all -i "$INVENTORY" -m ping | tee "$LOG_DIR/01_precheck.log"

# Run maintenance
echo "=== Executing All Collection Roles ==="
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

Running all collection roles together provides:

- **Comprehensive Maintenance**: Complete system updates in one operation
- **Consistent Configuration**: Same variables applied across all roles
- **Safe Execution**: Serial processing and built-in safety checks
- **Flexible Control**: Tag-based execution and variable overrides
- **Complete Logging**: Full audit trail of all maintenance activities

This approach is ideal for scheduled maintenance windows where you need complete system updates with minimal manual intervention.

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