# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-11-08

### Added
- Initial release of gregheffner.ubuntu_patching collection
- `k8_maintenance` role for Kubernetes cluster patching
  - Safe node draining and uncordoning
  - Datadog monitor management during maintenance
  - System updates with proper kubectl workflow
  - Configurable timeouts and retry settings
- `ubuntu_update` role for general Ubuntu system patching
  - APT package updates and optional distribution upgrades
  - Docker container restart capabilities
  - Configurable reboot handling (modern/legacy methods)
  - Post-reboot script execution support
- Example playbooks for different update scenarios
  - Weekly safe updates
  - Monthly comprehensive updates  
  - Docker-only updates
- Comprehensive documentation and usage examples
- Sample inventory configurations

### Features
- Conservative defaults for production safety
- Serial execution for Kubernetes nodes
- Comprehensive logging and error handling
- Datadog integration for monitor management
- Flexible configuration options
- Safety checks and validation

[1.0.0]: https://github.com/gregheffner/ansible-collection-ubuntu-patching/releases/tag/v1.0.0