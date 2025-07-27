# Contributing Kollaa Fleet to Kolla-Ansible

This guide explains how to contribute the Kollaa Fleet deployment automation toolset to the official Kolla-Ansible project.

## Prerequisites

1. GitHub account
2. Fork of the [kolla-ansible repository](https://github.com/openstack/kolla-ansible)
3. Git configured with your name and email
4. OpenStack Gerrit account (for official submission)

## Quick Start

### 1. Fork and Clone

```bash
# Fork kolla-ansible on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/kolla-ansible
cd kolla-ansible

# Add upstream remote
git remote add upstream https://github.com/openstack/kolla-ansible
```

### 2. Create Feature Branch

```bash
# Update master branch
git checkout master
git pull upstream master

# Create feature branch
git checkout -b add-kollaa-fleet-deployment

# Copy Kollaa Fleet files
cp -r /path/to/kollaa-fleet/* tools/kollaa-fleet/
```

### 3. Commit Changes

```bash
git add tools/kollaa-fleet/
git commit -m "Add Kollaa Fleet deployment automation toolset

This commit introduces Kollaa Fleet, an interactive deployment
automation toolset that simplifies multi-node OpenStack installations
using Kolla-Ansible.

Key features:
- Interactive installer with progress tracking
- Multi-node deployment configuration
- Automated network and storage setup
- Comprehensive rollback system
- Support for RHEL and Debian-based systems

Change-Id: I$(uuidgen | tr -d '-' | cut -c1-40)"
```

### 4. Push and Create PR

```bash
# Push to your fork
git push origin add-kollaa-fleet-deployment

# Create PR on GitHub (for initial review)
# Or submit to Gerrit (for official review)
```

## Using the Helper Script

We've included a helper script to automate the Git workflow:

```bash
./push-and-merge.sh
```

This script provides:
- Remote configuration setup
- Feature branch creation
- Update from upstream
- PR creation instructions
- Git status monitoring

## File Organization

When contributing to Kolla-Ansible, organize files as follows:

```
kolla-ansible/
└── tools/
    └── kollaa-fleet/
        ├── deploy-openstack.sh      # Main entry point
        ├── install.sh              # Configuration wizard
        ├── install-deploy.sh       # Deployment module
        ├── rollback.sh            # Rollback system
        ├── README.md              # Documentation
        ├── ROLLBACK-GUIDE.md      # Rollback documentation
        ├── requirements.txt       # Python dependencies
        ├── scripts/               # Helper scripts
        ├── inventories/           # Example inventories
        └── environments/          # Example configurations
```

## Commit Message Format

Follow OpenStack commit message conventions:

```
Add Kollaa Fleet deployment automation toolset

This commit introduces Kollaa Fleet, an interactive deployment
automation toolset that simplifies multi-node OpenStack installations
using Kolla-Ansible.

The toolset provides:
- Interactive configuration wizard with validation
- Automated multi-node deployment orchestration  
- Network and storage configuration automation
- Comprehensive rollback and cleanup procedures
- Cross-platform support for major Linux distributions

This addition helps operators deploy OpenStack more easily by providing
a user-friendly interface on top of Kolla-Ansible's powerful deployment
capabilities.

Implements: blueprint kollaa-fleet-deployment
Change-Id: I0123456789abcdef0123456789abcdef01234567
```

## Testing Requirements

Before submitting:

1. **Test on Multiple Platforms**
   - Rocky Linux 9
   - Ubuntu 22.04
   - Debian 12

2. **Test Deployment Scenarios**
   - All-in-one deployment
   - Multi-node (3 controllers, 2 compute)
   - With CEPH storage
   - With LVM storage

3. **Test Rollback**
   - Nuclear rollback
   - Kolla destroy only
   - Verify clean state

4. **Code Quality**
   ```bash
   # Check shell scripts
   shellcheck *.sh scripts/*.sh
   
   # Check YAML files
   yamllint inventories/*.yml environments/*/*.yml
   ```

## Documentation Updates

Include updates to official docs:

1. **doc/source/user/quickstart.rst**
   - Add section on using Kollaa Fleet

2. **doc/source/admin/deployment-tools.rst**
   - Document the interactive installer

3. **doc/source/reference/deployment/index.rst**
   - Add rollback procedures

## Pull Request Template

Use this template when creating your PR:

```markdown
## Summary

This PR adds Kollaa Fleet, an interactive deployment automation toolset for Kolla-Ansible.

## Problem

Currently, deploying OpenStack with Kolla-Ansible requires:
- Manual inventory creation
- Complex network configuration
- Multiple command executions
- No built-in rollback mechanism

## Solution

Kollaa Fleet provides:
- Interactive configuration wizard
- Automated inventory generation
- Step-by-step deployment process
- Comprehensive rollback system
- Progress tracking and validation

## Testing

- [ ] Tested on Rocky Linux 9
- [ ] Tested on Ubuntu 22.04
- [ ] Tested on Debian 12
- [ ] Multi-node deployment successful
- [ ] Rollback procedures verified
- [ ] Documentation updated

## Screenshots

[Include screenshots of the interactive installer]

## Related

- Implements: blueprint kollaa-fleet-deployment
- Closes: bug #12345 (if applicable)
```

## Review Process

### GitHub (Informal Review)

1. Create PR from your fork to openstack/kolla-ansible
2. Request review from community members
3. Address feedback and update

### Gerrit (Official Submission)

1. Set up Gerrit account: https://docs.openstack.org/contributors/
2. Install git-review: `pip install git-review`
3. Submit patch:
   ```bash
   git review
   ```

## Community Engagement

1. **Announce on IRC**: #openstack-kolla
2. **Email openstack-discuss**: [Kolla] Kollaa Fleet deployment toolset
3. **Create Launchpad Blueprint**: https://blueprints.launchpad.net/kolla-ansible

## Maintenance Commitment

By contributing Kollaa Fleet, we commit to:
- Responding to bug reports
- Updating for new Kolla-Ansible releases
- Reviewing related patches
- Maintaining documentation

## License

Ensure all files include the Apache 2.0 license header:

```python
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
```

## Questions?

- IRC: #openstack-kolla on OFTC
- Mailing List: openstack-discuss@lists.openstack.org
- Launchpad: https://launchpad.net/kolla-ansible

Happy contributing! 🚀