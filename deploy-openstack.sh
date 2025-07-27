#!/bin/bash
# Kollaa Fleet - Master Deployment Script
# Single entry point for the complete OpenStack deployment process

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        Kollaa Fleet Master Installer                        ║"
    echo "║                   Complete OpenStack Deployment Solution                    ║"
    echo "║                         Powered by Kolla-Ansible                           ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_menu() {
    echo -e "${WHITE}${BOLD}Available Actions:${NC}"
    echo -e "${CYAN}1.${NC} Configure deployment (collect information)"
    echo -e "${CYAN}2.${NC} Deploy OpenStack (requires configuration)"
    echo -e "${CYAN}3.${NC} Validate configuration"
    echo -e "${CYAN}4.${NC} Complete workflow (configure + deploy)"
    echo -e "${CYAN}5.${NC} ${BOLD}${RED}Rollback/Destroy deployment${NC}"
    echo -e "${CYAN}6.${NC} Clean up local configuration"
    echo -e "${CYAN}7.${NC} Show help"
    echo -e "${CYAN}8.${NC} Exit"
    echo ""
}

check_requirements() {
    echo -e "${BLUE}Checking system requirements...${NC}"
    
    # Check if running as non-root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}Error: This script should not be run as root${NC}"
        echo -e "${YELLOW}Please run as a regular user with sudo privileges${NC}"
        exit 1
    fi
    
    # Check basic commands
    local missing_commands=()
    for cmd in python3 git curl wget sudo; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required commands: ${missing_commands[*]}${NC}"
        echo -e "${YELLOW}Please install them and try again${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}System requirements check passed${NC}"
    echo ""
}

show_deployment_status() {
    local config_dir="$SCRIPT_DIR/deployment-config"
    
    if [[ -f "$config_dir/deployment.state" ]]; then
        source "$config_dir/deployment.state"
        echo -e "${GREEN}Found existing configuration:${NC}"
        echo -e "${CYAN}  Deployment Name: $DEPLOYMENT_NAME${NC}"
        echo -e "${CYAN}  OpenStack Release: $OPENSTACK_RELEASE${NC}"
        echo -e "${CYAN}  Controller Nodes: $CONTROLLER_COUNT${NC}"
        echo -e "${CYAN}  Compute Nodes: $COMPUTE_COUNT${NC}"
        if [[ "$DEPLOY_CEPH" == "true" ]]; then
            echo -e "${CYAN}  Storage Nodes: $STORAGE_COUNT (Ceph)${NC}"
        fi
        echo ""
    else
        echo -e "${YELLOW}No existing configuration found${NC}"
        echo ""
    fi
}

main_menu() {
    while true; do
        print_banner
        show_deployment_status
        show_menu
        
        echo -ne "${CYAN}Select an option [1-8]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                echo -e "${BLUE}Starting configuration wizard...${NC}"
                "$SCRIPT_DIR/install.sh"
                echo ""
                echo -e "${GREEN}Configuration completed. Press Enter to continue...${NC}"
                read -r
                ;;
            2)
                echo -e "${BLUE}Starting OpenStack deployment...${NC}"
                "$SCRIPT_DIR/install.sh" --deploy
                echo ""
                echo -e "${GREEN}Deployment completed. Press Enter to continue...${NC}"
                read -r
                ;;
            3)
                echo -e "${BLUE}Validating configuration...${NC}"
                "$SCRIPT_DIR/install.sh" --validate
                echo ""
                echo -e "${GREEN}Validation completed. Press Enter to continue...${NC}"
                read -r
                ;;
            4)
                echo -e "${BLUE}Starting complete workflow...${NC}"
                echo -e "${YELLOW}This will run configuration and deployment in sequence${NC}"
                echo -ne "${CYAN}Continue? (y/n): ${NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy] ]]; then
                    # Run configuration
                    "$SCRIPT_DIR/install.sh"
                    if [[ $? -eq 0 ]]; then
                        echo -e "${GREEN}Configuration completed successfully${NC}"
                        echo -e "${BLUE}Starting deployment...${NC}"
                        # Run deployment
                        "$SCRIPT_DIR/install.sh" --deploy
                    else
                        echo -e "${RED}Configuration failed. Deployment cancelled.${NC}"
                    fi
                fi
                echo ""
                echo -e "${GREEN}Workflow completed. Press Enter to continue...${NC}"
                read -r
                ;;
            5)
                echo -e "${RED}${BOLD}WARNING: This will destroy your OpenStack deployment!${NC}"
                echo -e "${YELLOW}Starting rollback system...${NC}"
                "$SCRIPT_DIR/rollback.sh"
                echo ""
                echo -e "${GREEN}Rollback completed. Press Enter to continue...${NC}"
                read -r
                ;;
            6)
                echo -e "${YELLOW}This will remove only local deployment configuration${NC}"
                echo -ne "${CYAN}Are you sure? (y/n): ${NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy] ]]; then
                    "$SCRIPT_DIR/install.sh" --cleanup
                fi
                echo ""
                echo -e "${GREEN}Cleanup completed. Press Enter to continue...${NC}"
                read -r
                ;;
            7)
                "$SCRIPT_DIR/install.sh" --help
                echo ""
                echo -e "${GREEN}Press Enter to continue...${NC}"
                read -r
                ;;
            8)
                echo -e "${GREEN}Thank you for using Kollaa Fleet!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-8.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Pre-flight checks
check_requirements

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Kollaa Fleet Master Installer"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  --help, -h       Show this help"
        echo "  --configure      Run configuration wizard only"
        echo "  --deploy         Run deployment only"
        echo "  --validate       Validate configuration"
        echo "  --cleanup        Clean up local configuration only"
        echo "  --rollback       Launch rollback/destroy system"
        echo "  --auto           Run complete workflow non-interactively"
        echo ""
        echo "Rollback Options:"
        echo "  --nuclear        Complete nuclear rollback (destroy everything)"
        echo "  --kolla-destroy  Use Kolla-Ansible destroy only"
        echo "  --remote-clean   Clean remote nodes only"
        echo ""
        echo "If no option is provided, the interactive menu will be shown."
        ;;
    --configure)
        "$SCRIPT_DIR/install.sh"
        ;;
    --deploy)
        "$SCRIPT_DIR/install.sh" --deploy
        ;;
    --validate)
        "$SCRIPT_DIR/install.sh" --validate
        ;;
    --cleanup)
        "$SCRIPT_DIR/install.sh" --cleanup
        ;;
    --rollback)
        "$SCRIPT_DIR/rollback.sh"
        ;;
    --nuclear)
        "$SCRIPT_DIR/rollback.sh" --nuclear
        ;;
    --kolla-destroy)
        "$SCRIPT_DIR/rollback.sh" --kolla-destroy
        ;;
    --remote-clean)
        "$SCRIPT_DIR/rollback.sh" --remote-only
        ;;
    --auto)
        echo -e "${BLUE}Running complete automated workflow...${NC}"
        "$SCRIPT_DIR/install.sh" && "$SCRIPT_DIR/install.sh" --deploy
        ;;
    *)
        main_menu
        ;;
esac