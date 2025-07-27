#!/bin/bash
# Kollaa Fleet Initial Setup Script
# This script ensures all files and directories are properly configured

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}Kollaa Fleet Initial Setup${NC}"
echo -e "${BLUE}=========================${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check and fix permissions
fix_permissions() {
    echo -e "${BLUE}Setting executable permissions on all scripts...${NC}"
    
    # Main scripts
    local scripts=(
        "deploy-openstack.sh"
        "install.sh"
        "install-deploy.sh"
        "rollback.sh"
        "setup.sh"
        "prepare-for-push.sh"
        "push-and-merge.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            chmod +x "$SCRIPT_DIR/$script"
            echo -e "${GREEN}✓ $script${NC}"
        else
            echo -e "${YELLOW}! $script not found${NC}"
        fi
    done
    
    # Scripts in subdirectories
    if [[ -d "$SCRIPT_DIR/scripts" ]]; then
        find "$SCRIPT_DIR/scripts" -name "*.sh" -type f -exec chmod +x {} \;
        echo -e "${GREEN}✓ All scripts in scripts/ directory${NC}"
    fi
}

# Function to create required directories
create_directories() {
    echo ""
    echo -e "${BLUE}Creating required directories...${NC}"
    
    local dirs=(
        "deployment-config"
        "scripts"
        "inventories"
        "environments/dev"
        "environments/staging"
        "environments/production"
        "templates"
        "docs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$SCRIPT_DIR/$dir"
        echo -e "${GREEN}✓ $dir${NC}"
    done
}

# Function to install missing dependencies
install_dependencies() {
    local deps_to_install=()
    local package_map=""
    
    # Detect OS
    if [[ -f /etc/redhat-release ]]; then
        OS_TYPE="rhel"
        # Package name mappings for RHEL-based systems
        package_map="pip3:python3-pip"
    elif [[ -f /etc/debian_version ]]; then
        OS_TYPE="debian"
        # Package name mappings for Debian-based systems
        package_map="pip3:python3-pip"
    else
        OS_TYPE="unknown"
    fi
    
    # Check each dependency
    for dep in "$@"; do
        # Get the correct package name
        local pkg_name="$dep"
        for mapping in $package_map; do
            IFS=':' read -r cmd pkg <<< "$mapping"
            if [[ "$dep" == "$cmd" ]]; then
                pkg_name="$pkg"
                break
            fi
        done
        deps_to_install+=("$pkg_name")
    done
    
    if [[ ${#deps_to_install[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}Installing missing dependencies: ${deps_to_install[*]}${NC}"
        
        if [[ "$OS_TYPE" == "rhel" ]]; then
            sudo dnf install -y "${deps_to_install[@]}" || sudo yum install -y "${deps_to_install[@]}"
        elif [[ "$OS_TYPE" == "debian" ]]; then
            sudo apt-get update && sudo apt-get install -y "${deps_to_install[@]}"
        else
            echo -e "${RED}Cannot automatically install dependencies on this OS${NC}"
            return 1
        fi
        
        echo -e "${GREEN}Dependencies installed successfully${NC}"
    fi
}

# Function to check dependencies
check_dependencies() {
    echo ""
    echo -e "${BLUE}Checking system dependencies...${NC}"
    
    local deps=(
        "python3:Python 3:python3"
        "pip3:Pip 3:python3-pip"
        "git:Git:git"
        "ansible:Ansible (optional):ansible"
        "ssh:SSH client:openssh-clients"
        "sshpass:SSH password authentication (optional):sshpass"
        "curl:Curl:curl"
        "wget:Wget:wget"
    )
    
    local missing=()
    local optional_missing=()
    
    for dep in "${deps[@]}"; do
        IFS=':' read -r cmd name pkg <<< "$dep"
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓ $name${NC}"
        else
            echo -e "${RED}✗ $name${NC}"
            if [[ "$name" =~ "optional" ]]; then
                optional_missing+=("$cmd")
            else
                missing+=("$cmd")
            fi
        fi
    done
    
    # Try to install missing required dependencies
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Missing required dependencies: ${missing[*]}${NC}"
        
        # Check if we have sudo access
        if sudo -n true 2>/dev/null; then
            echo -e "${BLUE}Attempting to install missing dependencies...${NC}"
            install_dependencies "${missing[@]}"
        else
            echo -e "${CYAN}Enter sudo password to install dependencies:${NC}"
            if sudo true; then
                install_dependencies "${missing[@]}"
            else
                echo -e "${RED}Cannot install dependencies without sudo access${NC}"
                return 1
            fi
        fi
    fi
    
    # Just inform about optional dependencies
    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Optional dependencies not installed: ${optional_missing[*]}${NC}"
        echo -e "${CYAN}These can be installed later if needed${NC}"
    fi
}

# Function to verify file integrity
verify_files() {
    echo ""
    echo -e "${BLUE}Verifying required files...${NC}"
    
    local required_files=(
        "deploy-openstack.sh"
        "install.sh"
        "install-deploy.sh"
        "rollback.sh"
        "README.md"
        "requirements.txt"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            echo -e "${GREEN}✓ $file${NC}"
        else
            echo -e "${RED}✗ $file${NC}"
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}ERROR: Missing required files!${NC}"
        echo -e "${RED}Please ensure all files are properly downloaded${NC}"
        return 1
    fi
}

# Function to create example files if missing
create_examples() {
    echo ""
    echo -e "${BLUE}Checking example files...${NC}"
    
    # Check if example files exist
    if [[ ! -f "$SCRIPT_DIR/inventories/multinode.yml.example" ]]; then
        echo -e "${YELLOW}Creating example inventory file...${NC}"
        touch "$SCRIPT_DIR/inventories/multinode.yml.example"
    fi
    
    if [[ ! -f "$SCRIPT_DIR/environments/production/globals.yml.example" ]]; then
        echo -e "${YELLOW}Creating example globals file...${NC}"
        touch "$SCRIPT_DIR/environments/production/globals.yml.example"
    fi
}

# Main setup process
main() {
    echo -e "${CYAN}Running initial setup...${NC}"
    echo ""
    
    # Run all setup steps
    fix_permissions
    create_directories
    verify_files || exit 1
    check_dependencies
    create_examples
    
    echo ""
    echo -e "${GREEN}${BOLD}Setup completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}You can now run:${NC}"
    echo -e "${WHITE}  ./deploy-openstack.sh${NC}     # Interactive installer"
    echo -e "${WHITE}  ./install.sh${NC}              # Configuration wizard"
    echo -e "${WHITE}  ./rollback.sh${NC}             # Rollback system"
    echo ""
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}Warning: Running as root. The installer should be run as a regular user.${NC}"
    echo -e "${YELLOW}Continue anyway? (y/n):${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Run main setup
main