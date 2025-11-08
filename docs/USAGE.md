# Ubuntu Patching Collection Usage Guide

## Quick Start

1. **Install the collection:**
   ```bash
   ansible-galaxy collection install gregheffner.ubuntu_patching
   ```

2. **Create an inventory file:**
   ```ini
   [ubuntu_servers]
   server1.example.com
   server2.example.com
   
   [k8s_cluster]
   k8-node-01
   k8-node-02
   ```

3. **Run a basic update playbook:**
   ```bash
   ansible-playbook -i inventory playbooks/ubuntu_updates.yml
   ```

## Available Playbooks

- `k8s_maintenance.yml` - Kubernetes cluster patching with monitor management
- `ubuntu_updates.yml` - Weekly safe Ubuntu updates
- `docker_updates.yml` - Docker container restart only

## Collection Structure

```
gregheffner.ubuntu_patching/
├── roles/
│   ├── k8_maintenance/         # Kubernetes cluster maintenance
│   └── ubuntu_update/          # Ubuntu system updates
├── playbooks/                  # Example playbooks
├── inventory/                  # Example inventory
└── docs/                      # Documentation
```

## Role Documentation

Each role includes comprehensive documentation:
- `/roles/k8_maintenance/README.md`
- `/roles/ubuntu_update/README.md`

## Safety Features

- Conservative defaults (dist-upgrade disabled)
- Serial execution for K8s nodes
- Proper kubectl drain/uncordon workflow
- Datadog monitor management
- Comprehensive logging

## Support

For issues and questions:
- GitHub: https://github.com/gregheffner/ansible-collection-ubuntu-patching
- Issues: https://github.com/gregheffner/ansible-collection-ubuntu-patching/issues