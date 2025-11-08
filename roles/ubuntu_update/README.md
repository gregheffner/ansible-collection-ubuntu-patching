# System Update Role

This Ansible role handles comprehensive system updates for Ubuntu systems, including Docker container management and optional reboot functionality.

## Features

- **Docker Management**: Restart all Docker containers to pick up latest configurations
- **Package Updates**: 
  - APT packages for Ubuntu systems (`apt update && apt upgrade`)
  - Safe weekly updates vs comprehensive monthly updates
- **System Maintenance**: Package cleanup and optional distribution upgrades  
- **Reboot Support**: Optional system reboot with configurable timeouts
- **Post-Reboot Scripts**: Run custom scripts after reboot (optional)

## Requirements

- Ansible 2.9+
- Ubuntu system (role will fail on non-Ubuntu systems)
- Appropriate privileges for package management (sudo/become)
- Docker (optional, for Docker-related tasks)

## Role Variables

### Docker Settings
```yaml
update_docker: true                    # Enable Docker tasks
restart_docker_containers: true       # Restart all containers
```

### Package Update Settings
```yaml
update_packages: true                  # Enable package updates
update_apt_packages: true             # Update APT packages (Ubuntu)
perform_dist_upgrade: false           # Perform distribution upgrade (default: false for safety)
cleanup_packages: true                # Clean up unused packages
```

### Reboot Settings
```yaml
perform_reboot: true                   # Enable automatic reboot (default: true)
force_reboot: true                     # Force reboot regardless of necessity
reboot_method: "legacy"               # "legacy" (shell command) or "modern" (reboot module) 
reboot_timeout: 600                   # Timeout for reboot operation
connect_timeout: 20                   # Connection timeout after reboot
```

### Post-Reboot Script (Optional)
```yaml
post_reboot_script_path: ""           # Path to script to run after reboot
# Example: post_reboot_script_path: "/opt/scripts/post-reboot.sh"
```

## Example Playbooks

### 1. Weekly Safe Updates (Recommended)
```yaml
---
- hosts: localhost
  become: true
  vars:
    perform_dist_upgrade: false        # Safe for automation
    perform_reboot: true              # Reboot after updates
    update_docker: true               # Restart Docker containers
  roles:
    - gregheffner.ubuntu-update
```

### 2. Monthly Comprehensive Updates
```yaml
---
- hosts: localhost
  become: true
  vars:
    perform_dist_upgrade: true        # More comprehensive
    perform_reboot: true
    update_docker: true
    cleanup_packages: true
  roles:
    - gregheffner.ubuntu-update
```

### 3. Docker-only Updates
```yaml
---
- hosts: localhost
  vars:
    update_packages: false            # Skip system packages
    perform_reboot: false            # No reboot needed
    update_docker: true              # Only restart Docker
  roles:
    - gregheffner.ubuntu-update
```

### 4. Basic Package Updates (No Reboot)
```yaml
---
- hosts: localhost
  become: true
  vars:
    perform_reboot: false            # Manual reboot later
  roles:
    - gregheffner.ubuntu-update
```

## Installation

### From Ansible Galaxy (Recommended)
```bash
# Install from Galaxy
ansible-galaxy install gregheffner.ubuntu-update

# Or add to requirements.yml
- name: gregheffner.ubuntu-update
```

### From GitHub
```bash
# Clone the repository
git clone https://github.com/gregheffner/ansible-role-ubuntu-update.git

# Copy role to your roles directory
cp -r ansible-role-ubuntu-update ~/.ansible/roles/

# Or use in requirements.yml
- src: https://github.com/gregheffner/ansible-role-ubuntu-update.git
  scm: git
  name: ubuntu_update
```

## What Gets Updated

| Component | Ubuntu | Notes |
|-----------|--------|-------|
| System Packages | APT (`apt update && apt upgrade`) | Safe weekly updates |
| Distribution Upgrade | Optional (`apt dist-upgrade`) | Disabled by default |
| Package Manager | APT | Updates package lists |
| Package Cleanup | `apt autoremove` | Removes unused packages |
| Docker Containers | Restart all | Picks up new configurations |

## Safety Features

- **Conservative Defaults**: `dist-upgrade` disabled by default for safety
- **Flexible Reboots**: Choose between modern (reboot module) or legacy methods
- **Fail-Safe**: Continue on errors for non-critical tasks
- **Detailed Reporting**: Shows what was updated and restart status

## File Structure
```
system_update/
├── defaults/main.yml      # Default variables
├── handlers/main.yml      # Event handlers  
├── meta/main.yml         # Role metadata
├── tasks/
│   ├── main.yml         # Main orchestration
│   ├── docker.yml       # Docker container management
│   ├── debian.yml       # Ubuntu package updates
│   └── reboot.yml       # Reboot and post-reboot tasks
└── README.md           # This documentation
```

## License

MIT

## Author Information

Created by [gregheffner](https://github.com/gregheffner) for automated system maintenance and updates.