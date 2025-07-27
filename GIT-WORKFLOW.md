# Git Workflow for Kollaa Fleet

## Quick Push Commands

### Option 1: Direct to Your Repository

```bash
# Initialize and push to your own repo
git init
git add .
git commit -m "Initial commit: Kollaa Fleet deployment automation"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/kollaa-fleet.git
git push -u origin main
```

### Option 2: Fork and Contribute to Kolla-Ansible

```bash
# 1. Fork kolla-ansible on GitHub first

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/kolla-ansible.git
cd kolla-ansible

# 3. Add upstream
git remote add upstream https://github.com/openstack/kolla-ansible.git

# 4. Create feature branch
git checkout -b add-kollaa-fleet
git pull upstream master

# 5. Copy Kollaa Fleet files
mkdir -p tools/kollaa-fleet
cp -r /path/to/kollaa-fleet/* tools/kollaa-fleet/

# 6. Commit
git add tools/kollaa-fleet/
git commit -m "Add Kollaa Fleet deployment automation toolset

This introduces an interactive deployment automation toolset
that simplifies multi-node OpenStack installations."

# 7. Push to your fork
git push origin add-kollaa-fleet

# 8. Create PR on GitHub
```

### Option 3: Using Helper Script

```bash
# Use the interactive helper
./push-and-merge.sh

# Select options:
# 1 - Initial setup (configure remotes)
# 2 - Create feature branch and push
# 4 - Get PR instructions
```

## Creating the Pull Request

### PR Title
```
Add Kollaa Fleet deployment automation toolset
```

### PR Description Template
```markdown
## Summary

This PR introduces Kollaa Fleet, an interactive deployment automation toolset for Kolla-Ansible that simplifies multi-node OpenStack installations.

## Key Features

- **Interactive Installer**: Step-by-step wizard with visual progress tracking
- **Multi-Node Support**: Automated configuration for controllers, compute, and storage
- **Network Automation**: Simplified network configuration with validation
- **Storage Integration**: Built-in CEPH and LVM support
- **Rollback System**: Safe and complete cleanup with triple confirmation
- **Cross-Platform**: Works on RHEL-based and Debian-based distributions

## What This Adds

- `tools/kollaa-fleet/deploy-openstack.sh` - Main entry point
- `tools/kollaa-fleet/install.sh` - Configuration wizard
- `tools/kollaa-fleet/rollback.sh` - Comprehensive rollback system
- Supporting scripts and documentation

## Benefits

1. Reduces deployment complexity for new users
2. Provides safe rollback procedures
3. Automates common configuration tasks
4. Maintains compatibility with existing workflows

## Testing

- Tested on Rocky Linux 9, Ubuntu 22.04, Debian 12
- Multi-node deployments validated
- Rollback procedures verified
- Compatible with OpenStack Yoga through Caracal

## Documentation

- README.md with quick start guide
- ROLLBACK-GUIDE.md for cleanup procedures
- Example configurations included
```

## Commit Message Best Practices

### Good Commit Message
```
Add Kollaa Fleet deployment automation toolset

This commit introduces Kollaa Fleet, an interactive deployment
automation toolset that simplifies multi-node OpenStack installations
using Kolla-Ansible.

The toolset provides:
- Interactive configuration wizard with input validation
- Automated multi-node inventory generation
- Network and storage configuration automation
- Comprehensive rollback system with safety checks
- Progress tracking and error handling

This helps operators deploy OpenStack more easily while maintaining
full compatibility with existing Kolla-Ansible workflows.

Closes-Bug: #123456 (if applicable)
Change-Id: Ixxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### For Multiple Commits
```bash
# Initial structure
git commit -m "Add Kollaa Fleet core installer scripts"

# Rollback system
git commit -m "Add comprehensive rollback system for Kollaa Fleet"

# Documentation
git commit -m "Add documentation for Kollaa Fleet"

# Examples
git commit -m "Add example configurations for Kollaa Fleet"
```

## Pre-Push Checklist

- [ ] All scripts are executable (`chmod +x`)
- [ ] License headers added (Apache 2.0)
- [ ] No hardcoded paths or credentials
- [ ] Documentation is complete
- [ ] Examples are working
- [ ] .gitignore excludes sensitive files

## After Creating PR

1. **Monitor CI**: Watch for OpenStack CI results
2. **Address Feedback**: Respond to reviewer comments
3. **Update as Needed**: Push fixes to the same branch
4. **Be Patient**: OpenStack reviews can take time

## Troubleshooting

### Permission Denied
```bash
# Fix permissions
find . -name "*.sh" -exec chmod +x {} \;
```

### Large Files
```bash
# Check file sizes
find . -size +1M -type f

# Add to .gitignore if needed
echo "large-file.dat" >> .gitignore
```

### Merge Conflicts
```bash
# Update from upstream
git fetch upstream
git rebase upstream/master

# Resolve conflicts
git status
# Edit conflicted files
git add .
git rebase --continue
```

## Support

- IRC: #openstack-kolla on OFTC
- Email: openstack-discuss@lists.openstack.org
- Issues: https://bugs.launchpad.net/kolla-ansible

---

Good luck with your contribution! 🚀