#!/bin/bash
# Kollaa Fleet - Comprehensive Rollback and Cleanup System
# This script provides complete rollback functionality with strong user confirmation

set -euo pipefail

# Source the main installer functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/deployment-config"
LOG_FILE="$CONFIG_DIR/rollback.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Icons
CHECK="✓"
CROSS="✗"
WARNING="⚠"
SKULL="💀"
FIRE="🔥"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Print dramatic banner
print_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    ${SKULL} KOLLAA FLEET ROLLBACK SYSTEM ${SKULL}                    ║"
    echo "║                        ${FIRE} DESTRUCTION MODE ACTIVATED ${FIRE}                        ║"
    echo "║                   ${WARNING} THIS WILL DESTROY YOUR DEPLOYMENT ${WARNING}                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Strong confirmation system
confirm_destruction() {
    local action="$1"
    local target="$2"
    
    echo -e "${RED}${BOLD}${WARNING} DANGER ZONE ${WARNING}${NC}"
    echo -e "${RED}You are about to: ${BOLD}$action${NC}"
    echo -e "${RED}Target: ${BOLD}$target${NC}"
    echo ""
    echo -e "${YELLOW}This action is ${BOLD}IRREVERSIBLE${NC}${YELLOW} and will:${NC}"
    echo -e "${RED}  ${CROSS} Destroy all OpenStack services${NC}"
    echo -e "${RED}  ${CROSS} Remove all Docker containers and images${NC}"
    echo -e "${RED}  ${CROSS} Delete all configuration files${NC}"
    echo -e "${RED}  ${CROSS} Clean up network bridges and interfaces${NC}"
    echo -e "${RED}  ${CROSS} Remove Ceph storage (if configured)${NC}"
    echo -e "${RED}  ${CROSS} Delete all virtual machines and data${NC}"
    echo ""
    echo -e "${PURPLE}${BOLD}Multiple confirmations are required:${NC}"
    echo ""
    
    # First confirmation
    echo -e "${CYAN}Step 1/3: Type 'I UNDERSTAND THE CONSEQUENCES' (case sensitive):${NC}"
    read -r confirm1
    if [[ "$confirm1" != "I UNDERSTAND THE CONSEQUENCES" ]]; then
        echo -e "${GREEN}Rollback cancelled. Your deployment is safe.${NC}"
        exit 0
    fi
    
    # Second confirmation
    echo ""
    echo -e "${CYAN}Step 2/3: Type 'DESTROY MY DEPLOYMENT' (case sensitive):${NC}"
    read -r confirm2
    if [[ "$confirm2" != "DESTROY MY DEPLOYMENT" ]]; then
        echo -e "${GREEN}Rollback cancelled. Your deployment is safe.${NC}"
        exit 0
    fi
    
    # Third confirmation with deployment name
    if [[ -f "$CONFIG_DIR/deployment.state" ]]; then
        source "$CONFIG_DIR/deployment.state"
        echo ""
        echo -e "${CYAN}Step 3/3: Type your deployment name '${BOLD}$DEPLOYMENT_NAME${NC}${CYAN}' to confirm:${NC}"
        read -r confirm3
        if [[ "$confirm3" != "$DEPLOYMENT_NAME" ]]; then
            echo -e "${GREEN}Rollback cancelled. Your deployment is safe.${NC}"
            exit 0
        fi
    else
        echo ""
        echo -e "${CYAN}Step 3/3: Type 'CONFIRMED' to proceed:${NC}"
        read -r confirm3
        if [[ "$confirm3" != "CONFIRMED" ]]; then
            echo -e "${GREEN}Rollback cancelled. Your deployment is safe.${NC}"
            exit 0
        fi
    fi
    
    # Final countdown
    echo ""
    echo -e "${RED}${BOLD}FINAL WARNING: Destruction will begin in 10 seconds...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to abort!${NC}"
    for i in {10..1}; do
        echo -ne "${RED}${BOLD}$i...${NC} "
        sleep 1
    done
    echo ""
    echo -e "${RED}${BOLD}BEGINNING DESTRUCTION...${NC}"
    echo ""
    
    log "User confirmed destruction: $action on $target"
}

# Backup current state before rollback
backup_before_rollback() {
    echo -e "${BLUE}Creating backup before rollback...${NC}"
    
    local backup_dir="$CONFIG_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup local configuration
    if [[ -f "$CONFIG_DIR/deployment.state" ]]; then
        cp "$CONFIG_DIR/deployment.state" "$backup_dir/"
    fi
    
    if [[ -f "$CONFIG_DIR/multinode" ]]; then
        cp "$CONFIG_DIR/multinode" "$backup_dir/"
    fi
    
    if [[ -f "$CONFIG_DIR/globals.yml" ]]; then
        cp "$CONFIG_DIR/globals.yml" "$backup_dir/"
    fi
    
    if [[ -f "$CONFIG_DIR/passwords.yml" ]]; then
        cp "$CONFIG_DIR/passwords.yml" "$backup_dir/"
    fi
    
    # Backup /etc/kolla if it exists
    if [[ -d "/etc/kolla" ]]; then
        sudo cp -r /etc/kolla "$backup_dir/" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}Backup created: $backup_dir${NC}"
    log "Backup created: $backup_dir"
}

# Remote cleanup script
create_remote_cleanup_script() {
    cat > /tmp/node_cleanup.sh <<'EOF'
#!/bin/bash
# Remote node cleanup script - Nuclear option

set -euo pipefail

echo "=== STARTING NUCLEAR CLEANUP ON $(hostname) ==="

# Stop all services first
systemctl stop docker 2>/dev/null || true
systemctl stop containerd 2>/dev/null || true
systemctl stop libvirtd 2>/dev/null || true

# Kill any remaining processes
pkill -f kolla 2>/dev/null || true
pkill -f docker 2>/dev/null || true
pkill -f containerd 2>/dev/null || true

# Remove Docker containers (if Docker is still running)
if command -v docker &> /dev/null; then
    echo "Removing all Docker containers..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    docker system prune -af 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
    
    # Remove all images
    docker rmi $(docker images -q) 2>/dev/null || true
fi

# Remove Docker and containerd data
echo "Removing container runtime data..."
rm -rf /var/lib/docker/
rm -rf /var/lib/containerd/
rm -rf /var/lib/dockershim/
rm -rf /run/docker/
rm -rf /run/containerd/

# Remove Kolla configuration and data
echo "Removing Kolla configuration..."
rm -rf /etc/kolla/
rm -rf /var/lib/kolla/
rm -rf /var/log/kolla/
rm -rf /opt/kolla/

# Remove OpenStack-related directories
echo "Removing OpenStack directories..."
rm -rf /etc/ceph/
rm -rf /var/lib/ceph/
rm -rf /var/log/ceph/
rm -rf /etc/neutron/
rm -rf /etc/nova/
rm -rf /etc/glance/
rm -rf /etc/keystone/
rm -rf /etc/cinder/
rm -rf /etc/heat/
rm -rf /etc/horizon/

# Remove network bridges and interfaces
echo "Cleaning up network configuration..."
for bridge in $(ip link show type bridge | grep -o 'br-[a-zA-Z0-9]*' | head -20); do
    echo "Removing bridge: $bridge"
    ip link set "$bridge" down 2>/dev/null || true
    ip link delete "$bridge" 2>/dev/null || true
done

# Remove OVS bridges
if command -v ovs-vsctl &> /dev/null; then
    echo "Removing OVS bridges..."
    for bridge in $(ovs-vsctl list-br 2>/dev/null); do
        ovs-vsctl del-br "$bridge" 2>/dev/null || true
    done
fi

# Clean up veth pairs and tap interfaces
for iface in $(ip link show | grep -E '(veth|tap|qbr|qvb|qvo)' | cut -d: -f2 | awk '{print $1}'); do
    echo "Removing interface: $iface"
    ip link delete "$iface" 2>/dev/null || true
done

# Remove iptables rules related to OpenStack
echo "Cleaning up iptables rules..."
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -t filter -F 2>/dev/null || true
iptables -t raw -F 2>/dev/null || true

# Remove systemd services created by Kolla
echo "Removing Kolla systemd services..."
for service in /etc/systemd/system/kolla-*; do
    if [[ -f "$service" ]]; then
        systemctl stop "$(basename "$service")" 2>/dev/null || true
        systemctl disable "$(basename "$service")" 2>/dev/null || true
        rm -f "$service"
    fi
done

# Remove cron jobs
echo "Removing Kolla cron jobs..."
crontab -l 2>/dev/null | grep -v kolla | crontab - 2>/dev/null || true

# Clean up logs
echo "Cleaning up log files..."
rm -rf /var/log/kolla*/
rm -rf /var/log/*kolla*
rm -rf /var/log/neutron*/
rm -rf /var/log/nova*/
rm -rf /var/log/glance*/

# Remove temporary files
echo "Removing temporary files..."
rm -rf /tmp/kolla*/
rm -rf /tmp/*kolla*

# Clean up LVM volumes if they exist
echo "Cleaning up LVM volumes..."
if command -v lvs &> /dev/null; then
    for lv in $(lvs --noheadings -o lv_name,vg_name | grep -E '(cinder|ceph)'); do
        lvremove -f "$lv" 2>/dev/null || true
    done
    
    for vg in $(vgs --noheadings -o vg_name | grep -E '(cinder|ceph)'); do
        vgremove -f "$vg" 2>/dev/null || true
    done
fi

# Clean up loop devices
echo "Cleaning up loop devices..."
for loop in $(losetup -a | grep -E '(cinder|ceph|kolla)' | cut -d: -f1); do
    losetup -d "$loop" 2>/dev/null || true
done

# Remove users created by OpenStack (if any)
echo "Cleaning up OpenStack users..."
for user in nova neutron glance keystone cinder heat ceph; do
    if id "$user" &>/dev/null; then
        userdel -r "$user" 2>/dev/null || true
    fi
done

# Clean up package caches
echo "Cleaning package caches..."
if command -v apt-get &> /dev/null; then
    apt-get autoremove -y 2>/dev/null || true
    apt-get autoclean 2>/dev/null || true
elif command -v dnf &> /dev/null; then
    dnf autoremove -y 2>/dev/null || true
    dnf clean all 2>/dev/null || true
elif command -v yum &> /dev/null; then
    yum autoremove -y 2>/dev/null || true
    yum clean all 2>/dev/null || true
fi

# Reload systemd
systemctl daemon-reload 2>/dev/null || true

echo "=== NUCLEAR CLEANUP COMPLETED ON $(hostname) ==="
echo "A reboot is highly recommended to ensure all changes take effect."
EOF

    chmod +x /tmp/node_cleanup.sh
}

# Execute Kolla-Ansible destroy
kolla_destroy() {
    echo -e "${RED}${BOLD}Running Kolla-Ansible destroy...${NC}"
    
    if [[ ! -f "$CONFIG_DIR/deployment.state" ]]; then
        echo -e "${YELLOW}No deployment state found, skipping Kolla destroy${NC}"
        return 0
    fi
    
    source "$CONFIG_DIR/deployment.state"
    
    # Activate virtual environment if it exists
    if [[ -f "$HOME/.kolla-venv/bin/activate" ]]; then
        source "$HOME/.kolla-venv/bin/activate"
    fi
    
    local inventory_file="$CONFIG_DIR/multinode"
    
    if [[ -f "$inventory_file" ]] && command -v kolla-ansible &> /dev/null; then
        echo -e "${BLUE}Running Kolla-Ansible destroy (this may take 10-15 minutes)...${NC}"
        
        # First try graceful destroy
        if kolla-ansible -i "$inventory_file" destroy --yes-i-really-really-mean-it; then
            echo -e "${GREEN}Kolla-Ansible destroy completed successfully${NC}"
        else
            echo -e "${YELLOW}Kolla-Ansible destroy failed or incomplete, proceeding with manual cleanup${NC}"
        fi
        
        # Additional cleanup that Kolla might miss
        echo -e "${BLUE}Running additional cleanup tasks...${NC}"
        
        # Stop all containers forcefully
        ansible all -i "$inventory_file" -m shell -a "docker stop \$(docker ps -aq) 2>/dev/null || true" || true
        ansible all -i "$inventory_file" -m shell -a "docker rm \$(docker ps -aq) 2>/dev/null || true" || true
        
        # Clean up networks
        ansible all -i "$inventory_file" -m shell -a "docker network prune -f" || true
        
        # Clean up volumes
        ansible all -i "$inventory_file" -m shell -a "docker volume prune -f" || true
        
    else
        echo -e "${YELLOW}Kolla-Ansible not available, proceeding with manual cleanup only${NC}"
    fi
}

# Remote node cleanup
remote_cleanup() {
    echo -e "${RED}${BOLD}Performing nuclear cleanup on all nodes...${NC}"
    
    if [[ ! -f "$CONFIG_DIR/deployment.state" ]]; then
        echo -e "${YELLOW}No deployment state found, cannot identify nodes${NC}"
        return 1
    fi
    
    source "$CONFIG_DIR/deployment.state"
    
    # Create cleanup script
    create_remote_cleanup_script
    
    # Get all node IPs
    local all_ips=()
    if [[ -n "${CONTROLLER_IPS:-}" ]]; then
        all_ips+=("${CONTROLLER_IPS[@]}")
    fi
    if [[ -n "${COMPUTE_IPS:-}" ]]; then
        all_ips+=("${COMPUTE_IPS[@]}")
    fi
    if [[ -n "${STORAGE_IPS:-}" ]]; then
        all_ips+=("${STORAGE_IPS[@]}")
    fi
    
    if [[ ${#all_ips[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No node IPs found in deployment state${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Cleaning up ${#all_ips[@]} nodes...${NC}"
    
    for ip in "${all_ips[@]}"; do
        echo -e "${CYAN}Cleaning node: $ip${NC}"
        
        # Copy cleanup script to remote node
        if scp /tmp/node_cleanup.sh "$SSH_USER@$ip:/tmp/"; then
            # Execute cleanup script
            if ssh "$SSH_USER@$ip" "sudo chmod +x /tmp/node_cleanup.sh && sudo /tmp/node_cleanup.sh"; then
                echo -e "${GREEN}${CHECK} Node $ip cleaned successfully${NC}"
                log "Node $ip cleaned successfully"
            else
                echo -e "${RED}${CROSS} Failed to clean node $ip${NC}"
                log "Failed to clean node $ip"
            fi
            
            # Remove cleanup script
            ssh "$SSH_USER@$ip" "sudo rm -f /tmp/node_cleanup.sh" || true
        else
            echo -e "${RED}${CROSS} Cannot connect to node $ip${NC}"
            log "Cannot connect to node $ip"
        fi
    done
    
    # Clean up local cleanup script
    rm -f /tmp/node_cleanup.sh
}

# Local cleanup
local_cleanup() {
    echo -e "${RED}${BOLD}Performing local cleanup...${NC}"
    
    # Remove virtual environment
    if [[ -d "$HOME/.kolla-venv" ]]; then
        echo -e "${CYAN}Removing Python virtual environment...${NC}"
        rm -rf "$HOME/.kolla-venv"
    fi
    
    # Remove Kolla configuration
    if [[ -d "/etc/kolla" ]]; then
        echo -e "${CYAN}Removing Kolla configuration...${NC}"
        sudo rm -rf /etc/kolla
    fi
    
    # Remove deployment configuration
    if [[ -d "$CONFIG_DIR" ]]; then
        echo -e "${CYAN}Removing deployment configuration...${NC}"
        rm -rf "$CONFIG_DIR"
    fi
    
    # Clean up SSH known_hosts entries
    if [[ -f "$HOME/.ssh/known_hosts" ]]; then
        echo -e "${CYAN}Cleaning SSH known_hosts...${NC}"
        if [[ -f "$CONFIG_DIR/deployment.state" ]]; then
            source "$CONFIG_DIR/deployment.state"
            local all_ips=("${CONTROLLER_IPS[@]:-}" "${COMPUTE_IPS[@]:-}" "${STORAGE_IPS[@]:-}")
            for ip in "${all_ips[@]}"; do
                [[ -n "$ip" ]] && ssh-keygen -R "$ip" 2>/dev/null || true
            done
        fi
    fi
    
    echo -e "${GREEN}${CHECK} Local cleanup completed${NC}"
}

# Reboot recommendation and handling
handle_reboots() {
    echo -e "${YELLOW}${BOLD}${WARNING} REBOOT RECOMMENDATION ${WARNING}${NC}"
    echo ""
    echo -e "${YELLOW}To ensure complete cleanup, it is ${BOLD}HIGHLY RECOMMENDED${NC}${YELLOW} to reboot all nodes.${NC}"
    echo -e "${YELLOW}This will clear any remaining kernel modules, network namespaces, and processes.${NC}"
    echo ""
    echo -e "${CYAN}Do you want to reboot all nodes now? (y/n):${NC}"
    read -r reboot_choice
    
    if [[ "$reboot_choice" =~ ^[Yy] ]]; then
        if [[ ! -f "$CONFIG_DIR/deployment.state" ]]; then
            echo -e "${RED}Cannot reboot nodes - no deployment state found${NC}"
            return 1
        fi
        
        source "$CONFIG_DIR/deployment.state"
        
        local all_ips=("${CONTROLLER_IPS[@]:-}" "${COMPUTE_IPS[@]:-}" "${STORAGE_IPS[@]:-}")
        
        echo -e "${RED}${BOLD}Rebooting all nodes in 10 seconds...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to abort!${NC}"
        for i in {10..1}; do
            echo -ne "${RED}$i... ${NC}"
            sleep 1
        done
        echo ""
        
        for ip in "${all_ips[@]}"; do
            if [[ -n "$ip" ]]; then
                echo -e "${CYAN}Rebooting node: $ip${NC}"
                ssh "$SSH_USER@$ip" "sudo shutdown -r +1 'Kollaa Fleet rollback reboot'" &
            fi
        done
        
        echo -e "${GREEN}Reboot commands sent to all nodes${NC}"
        echo -e "${YELLOW}Nodes will reboot in 1 minute${NC}"
        
    else
        echo -e "${YELLOW}Skipping automatic reboot${NC}"
        echo -e "${YELLOW}${BOLD}MANUAL REBOOT REQUIRED:${NC}"
        echo -e "${YELLOW}Please manually reboot all OpenStack nodes to ensure complete cleanup${NC}"
    fi
}

# Show rollback options
show_rollback_menu() {
    echo -e "${WHITE}${BOLD}Rollback Options:${NC}"
    echo -e "${RED}1.${NC} ${BOLD}Complete Nuclear Rollback${NC} - Destroy everything and clean all nodes"
    echo -e "${YELLOW}2.${NC} ${BOLD}Kolla-Ansible Destroy Only${NC} - Use Kolla's built-in destroy"
    echo -e "${BLUE}3.${NC} ${BOLD}Local Configuration Cleanup${NC} - Clean only local configuration"
    echo -e "${PURPLE}4.${NC} ${BOLD}Remote Node Cleanup${NC} - Clean only remote nodes"
    echo -e "${CYAN}5.${NC} ${BOLD}Show Current Deployment${NC} - Display deployment information"
    echo -e "${GREEN}6.${NC} ${BOLD}Cancel${NC} - Exit without changes"
    echo ""
}

# Complete nuclear rollback
nuclear_rollback() {
    print_banner
    echo -e "${RED}${BOLD}COMPLETE NUCLEAR ROLLBACK${NC}"
    echo -e "${RED}This will destroy EVERYTHING related to your OpenStack deployment${NC}"
    echo ""
    
    confirm_destruction "Complete Nuclear Rollback" "All OpenStack nodes and configuration"
    
    backup_before_rollback
    
    echo -e "${RED}${BOLD}Phase 1: Kolla-Ansible Destroy${NC}"
    kolla_destroy
    
    echo -e "${RED}${BOLD}Phase 2: Remote Node Nuclear Cleanup${NC}"
    remote_cleanup
    
    echo -e "${RED}${BOLD}Phase 3: Local Cleanup${NC}"
    local_cleanup
    
    echo -e "${RED}${BOLD}Phase 4: Reboot Handling${NC}"
    handle_reboots
    
    echo ""
    echo -e "${GREEN}${BOLD}${CHECK} NUCLEAR ROLLBACK COMPLETED SUCCESSFULLY ${CHECK}${NC}"
    echo -e "${GREEN}Your system has been restored to a clean state${NC}"
    log "Nuclear rollback completed successfully"
}

# Kolla destroy only
kolla_destroy_only() {
    print_banner
    echo -e "${YELLOW}${BOLD}KOLLA-ANSIBLE DESTROY ONLY${NC}"
    echo -e "${YELLOW}This will use Kolla's built-in destroy functionality${NC}"
    echo ""
    
    confirm_destruction "Kolla-Ansible Destroy" "OpenStack services via Kolla-Ansible"
    
    backup_before_rollback
    kolla_destroy
    
    echo -e "${YELLOW}${BOLD}Kolla destroy completed${NC}"
    echo -e "${YELLOW}Note: Some cleanup may require manual intervention or reboot${NC}"
    
    handle_reboots
}

# Show current deployment info
show_deployment_info() {
    if [[ ! -f "$CONFIG_DIR/deployment.state" ]]; then
        echo -e "${YELLOW}No deployment configuration found${NC}"
        return 1
    fi
    
    source "$CONFIG_DIR/deployment.state"
    
    echo -e "${CYAN}${BOLD}Current Deployment Information:${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo -e "${WHITE}Deployment Name:${NC} $DEPLOYMENT_NAME"
    echo -e "${WHITE}OpenStack Release:${NC} $OPENSTACK_RELEASE"
    echo -e "${WHITE}Base Distribution:${NC} $KOLLA_BASE_DISTRO"
    echo -e "${WHITE}Controller Nodes:${NC} $CONTROLLER_COUNT"
    echo -e "${WHITE}Compute Nodes:${NC} $COMPUTE_COUNT"
    if [[ "$DEPLOY_CEPH" == "true" ]]; then
        echo -e "${WHITE}Storage Nodes:${NC} $STORAGE_COUNT (Ceph enabled)"
    fi
    echo ""
    
    if [[ -n "${CONTROLLER_IPS:-}" ]]; then
        echo -e "${CYAN}Controller IPs:${NC}"
        for ip in "${CONTROLLER_IPS[@]}"; do
            echo -e "  • $ip"
        done
    fi
    
    if [[ -n "${COMPUTE_IPS:-}" ]]; then
        echo -e "${CYAN}Compute IPs:${NC}"
        for ip in "${COMPUTE_IPS[@]}"; do
            echo -e "  • $ip"
        done
    fi
    
    if [[ -n "${STORAGE_IPS:-}" ]]; then
        echo -e "${CYAN}Storage IPs:${NC}"
        for ip in "${STORAGE_IPS[@]}"; do
            echo -e "  • $ip"
        done
    fi
    echo ""
}

# Main menu
main() {
    # Create log directory
    mkdir -p "$CONFIG_DIR"
    
    while true; do
        clear
        print_banner
        show_rollback_menu
        
        echo -ne "${CYAN}Select an option [1-6]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                nuclear_rollback
                break
                ;;
            2)
                kolla_destroy_only
                break
                ;;
            3)
                confirm_destruction "Local Configuration Cleanup" "Local deployment configuration"
                backup_before_rollback
                local_cleanup
                echo -e "${GREEN}${CHECK} Local cleanup completed${NC}"
                break
                ;;
            4)
                confirm_destruction "Remote Node Cleanup" "All remote OpenStack nodes"
                backup_before_rollback
                remote_cleanup
                handle_reboots
                echo -e "${GREEN}${CHECK} Remote cleanup completed${NC}"
                break
                ;;
            5)
                show_deployment_info
                echo ""
                echo -e "${GREEN}Press Enter to continue...${NC}"
                read -r
                ;;
            6)
                echo -e "${GREEN}Rollback cancelled. Your deployment is safe.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-6.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Kollaa Fleet Rollback System"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  --help, -h        Show this help"
        echo "  --nuclear         Complete nuclear rollback (interactive)"
        echo "  --kolla-destroy   Kolla-Ansible destroy only"
        echo "  --local-only      Clean local configuration only"
        echo "  --remote-only     Clean remote nodes only"
        echo "  --show-info       Show deployment information"
        echo ""
        echo "If no option is provided, the interactive menu will be shown."
        ;;
    --nuclear)
        nuclear_rollback
        ;;
    --kolla-destroy)
        kolla_destroy_only
        ;;
    --local-only)
        confirm_destruction "Local Configuration Cleanup" "Local deployment configuration"
        backup_before_rollback
        local_cleanup
        ;;
    --remote-only)
        confirm_destruction "Remote Node Cleanup" "All remote OpenStack nodes"
        backup_before_rollback
        remote_cleanup
        handle_reboots
        ;;
    --show-info)
        show_deployment_info
        ;;
    *)
        main
        ;;
esac