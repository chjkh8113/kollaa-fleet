#!/bin/bash
# Git push and merge helper script for Kollaa Fleet

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
UPSTREAM_REPO="https://github.com/openstack/kolla-ansible"
ORIGIN_REPO=""  # Will be set by user
DEFAULT_BRANCH="main"
FEATURE_BRANCH="kollaa-fleet-deployment"

echo -e "${BLUE}${BOLD}Kollaa Fleet - Git Push and Merge Helper${NC}"
echo ""

# Check if git is initialized
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not a git repository${NC}"
    echo "Run 'git init' first"
    exit 1
fi

# Function to get current branch
get_current_branch() {
    git rev-parse --abbrev-ref HEAD
}

# Function to check uncommitted changes
check_uncommitted_changes() {
    if ! git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
        echo -e "${YELLOW}Please commit or stash them before proceeding${NC}"
        return 1
    fi
    return 0
}

# Main menu
show_menu() {
    echo -e "${BOLD}Select an action:${NC}"
    echo "1. Initial setup (configure remotes)"
    echo "2. Create feature branch and push"
    echo "3. Update from upstream"
    echo "4. Create pull request"
    echo "5. Push to origin"
    echo "6. Show git status"
    echo "7. Exit"
    echo ""
}

# Initial setup
initial_setup() {
    echo -e "${BLUE}Setting up Git remotes...${NC}"
    
    # Get user's fork URL
    echo -ne "${CYAN}Enter your GitHub fork URL (e.g., https://github.com/yourusername/kolla-ansible): ${NC}"
    read -r ORIGIN_REPO
    
    # Add remotes
    echo "Adding remotes..."
    
    # Check if origin exists
    if git remote | grep -q "^origin$"; then
        git remote set-url origin "$ORIGIN_REPO"
    else
        git remote add origin "$ORIGIN_REPO"
    fi
    
    # Check if upstream exists
    if git remote | grep -q "^upstream$"; then
        git remote set-url upstream "$UPSTREAM_REPO"
    else
        git remote add upstream "$UPSTREAM_REPO"
    fi
    
    echo -e "${GREEN}Remotes configured:${NC}"
    git remote -v
    
    # Fetch from remotes
    echo -e "${BLUE}Fetching from remotes...${NC}"
    git fetch origin || true
    git fetch upstream || true
    
    echo -e "${GREEN}Setup completed!${NC}"
}

# Create feature branch
create_feature_branch() {
    if ! check_uncommitted_changes; then
        return 1
    fi
    
    echo -e "${BLUE}Creating feature branch...${NC}"
    
    # Update main branch first
    git checkout "$DEFAULT_BRANCH" 2>/dev/null || git checkout -b "$DEFAULT_BRANCH"
    git pull upstream "$DEFAULT_BRANCH" || echo "Could not pull from upstream"
    
    # Create feature branch
    git checkout -b "$FEATURE_BRANCH"
    
    echo -e "${GREEN}Feature branch '$FEATURE_BRANCH' created${NC}"
    
    # Commit all files
    echo -e "${BLUE}Committing Kollaa Fleet files...${NC}"
    git add .
    git commit -m "Add Kollaa Fleet deployment automation

- Interactive installer with step-by-step progress tracking
- Multi-node deployment support for controllers, compute, and storage
- Automated network and storage configuration
- CEPH integration with automatic configuration
- Comprehensive rollback system with safety mechanisms
- Support for RHEL-based and Debian-based distributions
- Custom Kolla-Ansible configuration templates
- Pre-deployment validation and post-deployment setup

This toolset simplifies OpenStack deployment using Kolla-Ansible
by providing an interactive, user-friendly installation process
with proper error handling and rollback capabilities."
    
    # Push to origin
    echo -e "${BLUE}Pushing to origin...${NC}"
    git push -u origin "$FEATURE_BRANCH"
    
    echo -e "${GREEN}Feature branch pushed successfully!${NC}"
    echo -e "${YELLOW}Next step: Create a pull request on GitHub${NC}"
}

# Update from upstream
update_from_upstream() {
    if ! check_uncommitted_changes; then
        return 1
    fi
    
    current_branch=$(get_current_branch)
    
    echo -e "${BLUE}Updating from upstream...${NC}"
    
    # Fetch latest changes
    git fetch upstream
    
    # Merge or rebase
    echo -e "${CYAN}Select merge strategy:${NC}"
    echo "1. Merge (preserves commit history)"
    echo "2. Rebase (creates linear history)"
    read -r choice
    
    case $choice in
        1)
            git merge upstream/"$DEFAULT_BRANCH"
            ;;
        2)
            git rebase upstream/"$DEFAULT_BRANCH"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}Updated from upstream successfully${NC}"
}

# Create pull request instructions
create_pr_instructions() {
    echo -e "${BLUE}${BOLD}Creating Pull Request${NC}"
    echo ""
    echo -e "${YELLOW}Follow these steps to create a pull request:${NC}"
    echo ""
    echo "1. Go to your fork on GitHub:"
    echo "   ${ORIGIN_REPO}"
    echo ""
    echo "2. Click 'Pull requests' → 'New pull request'"
    echo ""
    echo "3. Set base repository: openstack/kolla-ansible"
    echo "   Set base branch: master"
    echo "   Set head repository: your-fork/kolla-ansible"
    echo "   Set compare branch: $FEATURE_BRANCH"
    echo ""
    echo "4. Use this PR title:"
    echo "   'Add Kollaa Fleet deployment automation toolset'"
    echo ""
    echo "5. Use this PR description:"
    cat << 'EOF'

## Description

This PR introduces Kollaa Fleet, a comprehensive deployment automation toolset for Kolla-Ansible that simplifies multi-node OpenStack deployments.

## Features

- **Interactive Installer**: Step-by-step wizard with progress tracking
- **Multi-Node Support**: Automated configuration for controllers, compute, and storage nodes
- **Network Configuration**: Automated setup for management, tunnel, and external networks
- **Storage Integration**: Built-in support for CEPH and LVM backends
- **Comprehensive Rollback**: Safe destruction and cleanup with triple confirmation
- **Cross-Platform**: Support for RHEL-based and Debian-based distributions
- **Pre-deployment Validation**: Automated checks for prerequisites
- **Custom Configuration**: Templates for service-specific configurations

## What This Adds

```
deploy-openstack.sh      # Master installer with interactive menu
install.sh              # Configuration wizard and deployment logic
install-deploy.sh       # Deployment execution module
rollback.sh            # Comprehensive rollback system
scripts/               # Helper scripts for validation and setup
inventories/           # Example multi-node inventory templates
environments/          # Environment-specific configuration examples
```

## Usage

```bash
# Interactive installation
./deploy-openstack.sh

# Or direct deployment
./deploy-openstack.sh --auto
```

## Benefits

1. **Reduces Deployment Time**: From hours to minutes with automation
2. **Prevents Errors**: Validated inputs and pre-deployment checks
3. **Simplifies Rollback**: Safe and complete cleanup procedures
4. **Improves Documentation**: Interactive help and guided setup

## Testing

- Tested on Rocky Linux 9, Ubuntu 22.04, and Debian 12
- Supports OpenStack releases from Yoga to Caracal
- Validated with 3-controller, 2-compute, 3-storage configurations

## Documentation

- Comprehensive README.md with quick start guide
- CLAUDE.md for AI-assisted development
- ROLLBACK-GUIDE.md for safe cleanup procedures

This toolset maintains full compatibility with existing Kolla-Ansible workflows while adding a user-friendly layer for common deployment scenarios.

EOF
    
    echo ""
    echo -e "${GREEN}Copy the above description when creating your PR${NC}"
}

# Push to origin
push_to_origin() {
    current_branch=$(get_current_branch)
    
    echo -e "${BLUE}Pushing to origin...${NC}"
    git push origin "$current_branch"
    
    echo -e "${GREEN}Pushed to origin successfully${NC}"
}

# Show status
show_status() {
    echo -e "${BLUE}${BOLD}Git Status${NC}"
    echo ""
    echo -e "${CYAN}Current branch:${NC} $(get_current_branch)"
    echo ""
    echo -e "${CYAN}Remotes:${NC}"
    git remote -v
    echo ""
    echo -e "${CYAN}Recent commits:${NC}"
    git log --oneline -5
    echo ""
    echo -e "${CYAN}Status:${NC}"
    git status -s
}

# Main loop
main() {
    while true; do
        echo ""
        show_menu
        
        echo -ne "${CYAN}Select option [1-7]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                initial_setup
                ;;
            2)
                create_feature_branch
                ;;
            3)
                update_from_upstream
                ;;
            4)
                create_pr_instructions
                ;;
            5)
                push_to_origin
                ;;
            6)
                show_status
                ;;
            7)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo ""
        echo -e "${GREEN}Press Enter to continue...${NC}"
        read -r
    done
}

# Run main
main