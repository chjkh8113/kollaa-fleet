# Kollaa Fleet - Multi-Node OpenStack Deployment

Automated deployment framework for installing Kolla-Ansible OpenStack on multiple bare metal servers with pre-installed Linux distributions.

## Overview

This project simplifies the deployment of OpenStack using Kolla-Ansible on bare metal infrastructure. It provides:

- Pre-configured inventory templates for multi-node deployments
- Environment-specific configuration management
- Automated pre-deployment validation
- Network configuration scripts
- Best practices and deployment guides

## Supported Operating Systems

### Host Operating Systems
- Rocky Linux 9
- CentOS Stream 9
- Debian 12 (Bookworm)
- Ubuntu 24.04 (Noble)

## Prerequisites

- Bare metal servers with one of the supported Linux distributions installed
- Minimum 2 network interfaces per server
- 8GB RAM minimum (16GB+ recommended for production)
- 40GB disk space minimum
- Python 3.8+ on deployment host
- SSH access to all target nodes

## Quick Start

### Interactive Installation (Recommended)

1. **Clone this repository**
   ```bash
   git clone https://github.com/yourusername/kollaa-fleet.git
   cd kollaa-fleet
   ```

2. **Run the interactive installer**
   ```bash
   ./deploy-openstack.sh
   ```
   
   The installer will guide you through:
   - Node discovery and validation
   - Network configuration
   - Storage setup (including Ceph)
   - Service selection
   - Automated deployment

### Command Line Installation

1. **Configure deployment**
   ```bash
   ./deploy-openstack.sh --configure
   ```

2. **Deploy OpenStack**
   ```bash
   ./deploy-openstack.sh --deploy
   ```

3. **Or run complete workflow**
   ```bash
   ./deploy-openstack.sh --auto
   ```

### Rollback and Cleanup

If you need to remove your OpenStack deployment:

1. **Complete destruction (recommended)**
   ```bash
   ./deploy-openstack.sh --rollback
   # or directly
   ./rollback.sh
   ```

2. **Quick options**
   ```bash
   # Nuclear option - destroys everything
   ./deploy-openstack.sh --nuclear
   
   # Use Kolla's built-in destroy
   ./deploy-openstack.sh --kolla-destroy
   
   # Clean only remote nodes
   ./deploy-openstack.sh --remote-clean
   ```

**⚠️ WARNING**: Rollback operations are destructive and irreversible. Always backup important data first.

### Manual Installation

1. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure inventory**
   ```bash
   cp inventories/multinode.yml.example inventories/multinode.yml
   # Edit inventories/multinode.yml with your node details
   ```

3. **Configure environment**
   ```bash
   cp environments/production/globals.yml.example environments/production/globals.yml
   # Edit globals.yml with your network settings
   ```

4. **Run pre-deployment checks**
   ```bash
   ./scripts/pre-deployment-check.sh
   ```

5. **Deploy OpenStack**
   ```bash
   # Bootstrap servers
   kolla-ansible -i inventories/multinode bootstrap-servers
   
   # Run pre-checks
   kolla-ansible -i inventories/multinode prechecks
   
   # Deploy
   kolla-ansible -i inventories/multinode deploy
   
   # Post-deployment
   kolla-ansible -i inventories/multinode post-deploy
   ```

## Project Structure

```
kollaa-fleet/
├── inventories/           # Ansible inventory files
├── environments/          # Environment-specific configurations
├── scripts/              # Automation scripts
├── templates/            # Configuration templates
├── docs/                 # Additional documentation
└── site.yml             # Main Ansible playbook
```

## Documentation

- [Installation Guide](docs/installation.md)
- [Network Configuration](docs/networking.md)
- [Multi-Node Setup](docs/multinode.md)
- [Troubleshooting](docs/troubleshooting.md)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [OpenStack Kolla-Ansible](https://github.com/openstack/kolla-ansible) - The core deployment framework
- OpenStack community for comprehensive documentation