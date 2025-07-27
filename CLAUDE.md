# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kollaa-fleet is a deployment automation project for installing Kolla-Ansible OpenStack on multiple bare metal servers with pre-installed Linux (RHEL-based or Debian-based distributions). This project provides infrastructure-as-code templates, automation scripts, and best practices for multi-node OpenStack deployments.

## Technology Stack

- **Ansible**: Core automation tool
- **Python**: Scripting and tooling
- **Kolla-Ansible**: OpenStack deployment framework
- **Docker**: Container runtime for OpenStack services
- **Bash**: System scripts and utilities

## Common Development Commands

```bash
# Interactive installer (recommended for new deployments)
./deploy-openstack.sh

# Run configuration wizard only
./deploy-openstack.sh --configure

# Deploy with existing configuration
./deploy-openstack.sh --deploy

# Complete automated workflow
./deploy-openstack.sh --auto

# Validate existing configuration
./deploy-openstack.sh --validate

# Clean up local configuration only
./deploy-openstack.sh --cleanup

# Rollback/Destroy deployment
./deploy-openstack.sh --rollback        # Interactive rollback menu
./deploy-openstack.sh --nuclear         # Complete nuclear destruction
./deploy-openstack.sh --kolla-destroy   # Kolla-Ansible destroy only
./deploy-openstack.sh --remote-clean    # Clean remote nodes only

# Direct rollback script access
./rollback.sh                           # Interactive menu
./rollback.sh --nuclear                 # Nuclear rollback
./rollback.sh --kolla-destroy           # Kolla destroy only
./rollback.sh --local-only              # Local cleanup only
./rollback.sh --remote-only             # Remote cleanup only

# Manual commands for advanced users
pip install -r requirements.txt
./scripts/pre-deployment-check.sh
kolla-ansible -i inventories/multinode bootstrap-servers
kolla-ansible -i inventories/multinode prechecks
kolla-ansible -i inventories/multinode deploy
kolla-ansible -i inventories/multinode post-deploy
```

## Project Structure

```
kollaa-fleet/
├── inventories/           # Ansible inventory files for different deployments
│   ├── multinode.yml     # Template for multi-node deployments
│   └── dev/              # Development environment specific
├── environments/          # Environment-specific configurations
│   ├── dev/              # Development globals.yml and configs
│   ├── staging/          # Staging environment configs
│   └── production/       # Production environment configs
├── scripts/              # Automation and utility scripts
│   ├── pre-deployment-check.sh
│   ├── setup-networking.sh
│   └── backup-configs.sh
├── templates/            # Configuration templates
│   ├── globals.yml.j2    # Kolla globals template
│   └── multinode.j2      # Inventory template
├── docs/                 # Additional documentation
└── site.yml             # Main Ansible playbook
```

## Architecture Overview

### Network Architecture
- **Management Network**: Internal API communication between OpenStack services
- **Tenant Network**: VM-to-VM traffic (VXLAN/VLAN)
- **External Network**: Public API access and floating IPs
- **Storage Network**: Optional dedicated network for storage traffic

### Node Types
- **Control Nodes**: Run control plane services (API, scheduler, database)
- **Compute Nodes**: Run hypervisor and VM instances
- **Storage Nodes**: Provide block/object storage services
- **Network Nodes**: Handle network routing and DHCP

### Key Components
1. **Pre-deployment Validation**: Checks OS compatibility, network connectivity, and prerequisites
2. **Network Configuration**: Automated setup of bridges, bonds, and VLANs
3. **Kolla-Ansible Integration**: Wrapper scripts for common operations
4. **Environment Management**: Separate configs for dev/staging/prod
5. **Backup and Recovery**: Scripts for configuration backup

## Important Configuration Files

- `inventories/multinode.yml`: Defines which services run on which nodes
- `environments/*/globals.yml`: Kolla-Ansible main configuration
- `environments/*/passwords.yml`: Service passwords (auto-generated)
- `/etc/kolla/`: Runtime configuration directory on target hosts

## Deployment Workflow

1. **Prepare Inventory**: Define nodes and their roles
2. **Configure Network**: Set up network interfaces and bridges
3. **Bootstrap Servers**: Install Docker and dependencies
4. **Run Pre-checks**: Validate environment readiness
5. **Deploy OpenStack**: Install and configure all services
6. **Post-deployment**: Generate admin credentials and test

## Testing

```bash
# Run ansible syntax check
ansible-playbook site.yml --syntax-check

# Run deployment in check mode
ansible-playbook -i inventories/dev/hosts site.yml --check

# Validate Kolla-Ansible configuration
kolla-ansible -i inventories/multinode validate-config
```

## Troubleshooting Commands

```bash
# Check Docker container status
docker ps -a

# View Kolla logs
docker logs <container_name>

# Check service connectivity
kolla-ansible -i inventories/multinode check

# Reconfigure a service
kolla-ansible -i inventories/multinode reconfigure -t <service>

# Emergency MariaDB recovery
kolla-ansible -i inventories/multinode mariadb_recovery
```

## Rollback System

The project includes a comprehensive rollback system (`rollback.sh`) with multiple safety mechanisms:

### Safety Features
- **Triple confirmation system** with typed confirmations
- **10-second countdown** before destruction begins
- **Automatic backup** creation before rollback
- **Deployment name verification** for extra safety

### Rollback Options
1. **Nuclear Rollback**: Complete destruction of everything
   - Runs Kolla-Ansible destroy
   - Executes remote node cleanup scripts
   - Removes all local configuration
   - Handles server reboots

2. **Kolla Destroy Only**: Uses Kolla's built-in destroy functionality
3. **Local Cleanup**: Removes only local configuration
4. **Remote Cleanup**: Cleans only remote nodes

### What Gets Cleaned
- All Docker containers and images
- OpenStack configuration files (`/etc/kolla`, `/etc/ceph`, etc.)
- Network bridges and interfaces (br-*, veth*, tap*)
- LVM volumes and loop devices
- Systemd services created by Kolla
- Log files and temporary files
- User accounts created by OpenStack

### Reboot Handling
The rollback system addresses Kolla's limitation by:
- Providing automated reboot options
- Explaining why reboots are necessary
- Offering manual reboot instructions
- Cleaning up kernel modules and network namespaces

## Best Practices

1. Always run pre-checks before deployment
2. Keep separate password files for each environment
3. Use version control for inventory and configuration files
4. Test changes in dev environment first
5. Backup `/etc/kolla` before any major changes
6. Monitor disk space in `/var/lib/docker`
7. Use odd number of control nodes (3 or 5) for HA
8. **Always backup important data before rollback operations**
9. **Reboot nodes after rollback for complete cleanup**
10. **Test rollback procedures in development environment first**