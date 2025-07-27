#!/bin/bash
# Kollaa Fleet - Interactive OpenStack Deployment Installer
# This script guides users through a complete Kolla-Ansible OpenStack deployment

set -euo pipefail

# Color codes and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Icons
CHECK="✓"
CROSS="✗"
INFO="ℹ"
ARROW="→"

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/deployment-config"
LOG_FILE="$CONFIG_DIR/deployment.log"
INVENTORY_FILE="$CONFIG_DIR/multinode"
GLOBALS_FILE="$CONFIG_DIR/globals.yml"
PASSWORDS_FILE="$CONFIG_DIR/passwords.yml"

# Create necessary directories early
mkdir -p "$CONFIG_DIR"
mkdir -p "$SCRIPT_DIR/scripts"
mkdir -p "$SCRIPT_DIR/inventories"
mkdir -p "$SCRIPT_DIR/environments/dev"
mkdir -p "$SCRIPT_DIR/environments/staging"
mkdir -p "$SCRIPT_DIR/environments/production"
mkdir -p "$SCRIPT_DIR/templates"
mkdir -p "$SCRIPT_DIR/docs"

# Ensure all .sh files are executable
find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true

# Step tracking
TOTAL_STEPS=15
CURRENT_STEP=0
declare -a STEP_STATUS=()
declare -a STEP_NAMES=(
    "Environment Setup"
    "User Information Collection"
    "Node Discovery"
    "Network Configuration"
    "Storage Configuration"
    "OpenStack Configuration"
    "Dependencies Installation"
    "SSH Key Configuration"
    "Inventory Generation"
    "Globals Configuration"
    "Custom Configuration Setup"
    "Pre-deployment Validation"
    "Kolla-Ansible Bootstrap"
    "OpenStack Deployment"
    "Post-deployment Setup"
)

# Initialize all steps as pending
for i in $(seq 0 $((TOTAL_STEPS-1))); do
    STEP_STATUS[$i]="PENDING"
done

# Logging function
log() {
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Print banner
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        Kollaa Fleet Installer                               ║"
    echo "║                   Interactive OpenStack Deployment                          ║"
    echo "║                         Powered by Kolla-Ansible                           ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Progress display
show_progress() {
    echo -e "${WHITE}${BOLD}Deployment Progress:${NC}"
    echo -e "${WHITE}${BOLD}═══════════════════${NC}"
    
    for i in $(seq 0 $((TOTAL_STEPS-1))); do
        local status_icon=""
        local status_color=""
        
        case "${STEP_STATUS[$i]}" in
            "COMPLETED")
                status_icon="${CHECK}"
                status_color="${GREEN}"
                ;;
            "FAILED")
                status_icon="${CROSS}"
                status_color="${RED}"
                ;;
            "IN_PROGRESS")
                status_icon="${ARROW}"
                status_color="${YELLOW}"
                ;;
            *)
                status_icon="○"
                status_color="${WHITE}"
                ;;
        esac
        
        echo -e "${status_color}${status_icon} Step $((i+1)): ${STEP_NAMES[$i]}${NC}"
    done
    echo ""
}

# Update step status
update_step() {
    local step_num=$1
    local status=$2
    STEP_STATUS[$step_num]="$status"
    CURRENT_STEP=$step_num
}

# Error handler
error_exit() {
    local error_message="$1"
    update_step $CURRENT_STEP "FAILED"
    echo -e "${RED}${BOLD}ERROR: $error_message${NC}" | tee -a "$LOG_FILE"
    show_progress
    echo -e "${RED}Deployment failed. Check $LOG_FILE for details.${NC}"
    exit 1
}

# Success message
success_message() {
    local message="$1"
    echo -e "${GREEN}${CHECK} $message${NC}" | tee -a "$LOG_FILE"
}

# Info message
info_message() {
    local message="$1"
    echo -e "${BLUE}${INFO} $message${NC}" | tee -a "$LOG_FILE"
}

# Warning message
warning_message() {
    local message="$1"
    echo -e "${YELLOW}⚠ $message${NC}" | tee -a "$LOG_FILE"
}

# User input with validation
read_input() {
    local prompt="$1"
    local var_name="$2"
    local validation_func="${3:-}"
    local default_value="${4:-}"
    
    while true; do
        if [[ -n "$default_value" ]]; then
            echo -ne "${CYAN}$prompt [${default_value}]: ${NC}"
        else
            echo -ne "${CYAN}$prompt: ${NC}"
        fi
        
        read -r input
        
        if [[ -z "$input" && -n "$default_value" ]]; then
            input="$default_value"
        fi
        
        if [[ -z "$validation_func" ]] || $validation_func "$input"; then
            eval "$var_name='$input'"
            break
        else
            echo -e "${RED}Invalid input. Please try again.${NC}"
        fi
    done
}

# Validation functions
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        echo -e "${RED}Invalid IP address format${NC}"
        return 1
    fi
}

validate_positive_number() {
    local num="$1"
    if [[ $num =~ ^[0-9]+$ ]] && [[ $num -gt 0 ]]; then
        return 0
    else
        echo -e "${RED}Must be a positive number${NC}"
        return 1
    fi
}

validate_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        return 0
    else
        echo -e "${RED}File does not exist: $file${NC}"
        return 1
    fi
}

# Step 1: Environment Setup
step_environment_setup() {
    update_step 0 "IN_PROGRESS"
    log "Starting environment setup"
    
    # Create all necessary directories
    info_message "Creating required directories..."
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$SCRIPT_DIR/scripts"
    mkdir -p "$SCRIPT_DIR/inventories"
    mkdir -p "$SCRIPT_DIR/environments/dev"
    mkdir -p "$SCRIPT_DIR/environments/staging"
    mkdir -p "$SCRIPT_DIR/environments/production"
    mkdir -p "$SCRIPT_DIR/templates"
    mkdir -p "$SCRIPT_DIR/docs"
    
    # Ensure all scripts are executable
    info_message "Setting executable permissions on scripts..."
    find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    # Check if running as non-root
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        info_message "Testing sudo access..."
        if ! sudo true; then
            error_exit "This script requires sudo privileges"
        fi
    fi
    
    # Check required commands
    local missing_commands=()
    for cmd in python3 pip3 git ansible ssh sshpass; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        warning_message "Missing commands: ${missing_commands[*]}"
        warning_message "Some functionality may be limited"
    fi
    
    success_message "Environment setup completed"
    update_step 0 "COMPLETED"
}

# Step 2: User Information Collection
step_collect_user_info() {
    update_step 1 "IN_PROGRESS"
    show_progress
    
    echo -e "${WHITE}${BOLD}=== OpenStack Deployment Configuration ===${NC}"
    echo ""
    
    # Collect basic deployment information
    read_input "Deployment name" DEPLOYMENT_NAME "" "production"
    read_input "OpenStack release (yoga/zed/antelope/bobcat/caracal)" OPENSTACK_RELEASE "" "caracal"
    read_input "Kolla base distribution (rocky/ubuntu/debian)" KOLLA_BASE_DISTRO "" "rocky"
    
    echo ""
    echo -e "${WHITE}${BOLD}=== Node Configuration ===${NC}"
    
    # Controller nodes
    read_input "Number of controller nodes (recommended: 3 or 5 for HA)" CONTROLLER_COUNT validate_positive_number "3"
    
    # Compute nodes
    read_input "Number of compute nodes" COMPUTE_COUNT validate_positive_number "2"
    
    # Storage nodes
    echo ""
    echo -e "${CYAN}Do you want to deploy Ceph storage? (y/n):${NC}"
    read -r deploy_ceph
    if [[ "$deploy_ceph" =~ ^[Yy] ]]; then
        DEPLOY_CEPH=true
        read_input "Number of storage nodes (minimum 3 for Ceph)" STORAGE_COUNT validate_positive_number "3"
    else
        DEPLOY_CEPH=false
        STORAGE_COUNT=0
    fi
    
    echo ""
    echo -e "${WHITE}${BOLD}=== Authentication Method ===${NC}"
    echo "1) SSH Key (recommended)"
    echo "2) Password"
    read_input "Choose authentication method (1 or 2)" AUTH_METHOD validate_positive_number "1"
    
    if [[ "$AUTH_METHOD" == "1" ]]; then
        read_input "SSH private key path" SSH_KEY_PATH validate_file_exists "$HOME/.ssh/id_rsa"
        SSH_USER=""
        while [[ -z "$SSH_USER" ]]; do
            read_input "SSH username" SSH_USER
        done
    else
        SSH_KEY_PATH=""
        read_input "SSH username" SSH_USER "" "root"
        echo -ne "${CYAN}SSH password: ${NC}"
        read -rs SSH_PASSWORD
        echo ""
    fi
    
    success_message "User information collected"
    update_step 1 "COMPLETED"
}

# Step 3: Node Discovery
step_node_discovery() {
    update_step 2 "IN_PROGRESS"
    show_progress
    
    echo -e "${WHITE}${BOLD}=== Node Discovery ===${NC}"
    echo ""
    
    declare -a CONTROLLER_IPS=()
    declare -a COMPUTE_IPS=()
    declare -a STORAGE_IPS=()
    
    # Collect controller IPs
    info_message "Collecting controller node IPs..."
    for i in $(seq 1 "$CONTROLLER_COUNT"); do
        read_input "Controller $i IP address" controller_ip validate_ip
        CONTROLLER_IPS+=("$controller_ip")
    done
    
    # Collect compute IPs
    info_message "Collecting compute node IPs..."
    for i in $(seq 1 "$COMPUTE_COUNT"); do
        read_input "Compute $i IP address" compute_ip validate_ip
        COMPUTE_IPS+=("$compute_ip")
    done
    
    # Collect storage IPs if needed
    if [[ "$DEPLOY_CEPH" == true ]]; then
        info_message "Collecting storage node IPs..."
        for i in $(seq 1 "$STORAGE_COUNT"); do
            read_input "Storage $i IP address" storage_ip validate_ip
            STORAGE_IPS+=("$storage_ip")
        done
    fi
    
    # Test connectivity to all nodes
    info_message "Testing connectivity to all nodes..."
    
    local all_ips=("${CONTROLLER_IPS[@]}" "${COMPUTE_IPS[@]}")
    if [[ "$DEPLOY_CEPH" == true ]]; then
        all_ips+=("${STORAGE_IPS[@]}")
    fi
    
    for ip in "${all_ips[@]}"; do
        if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
            success_message "Node $ip is reachable"
        else
            error_exit "Node $ip is not reachable"
        fi
    done
    
    success_message "All nodes are reachable"
    update_step 2 "COMPLETED"
}

# Step 4: Network Configuration
step_network_configuration() {
    update_step 3 "IN_PROGRESS"
    show_progress
    
    echo -e "${WHITE}${BOLD}=== Network Configuration ===${NC}"
    echo ""
    
    # Management network
    read_input "Management network interface" MANAGEMENT_INTERFACE "" "eth0"
    read_input "Management network subnet (CIDR)" MANAGEMENT_SUBNET "" "10.0.0.0/24"
    read_input "Management network gateway" MANAGEMENT_GATEWAY validate_ip "10.0.0.1"
    
    # API networks
    read_input "Internal API network interface" API_INTERFACE "" "$MANAGEMENT_INTERFACE"
    read_input "Internal VIP address" INTERNAL_VIP validate_ip "10.0.0.10"
    
    # External network
    read_input "External network interface" EXTERNAL_INTERFACE "" "eth1"
    read_input "External VIP address" EXTERNAL_VIP validate_ip
    read_input "Public API subnet (CIDR)" PUBLIC_SUBNET "" "192.168.1.0/24"
    
    # Tunnel network
    read_input "Tunnel network interface" TUNNEL_INTERFACE "" "$MANAGEMENT_INTERFACE"
    
    # Neutron external interface
    read_input "Neutron external interface (for floating IPs)" NEUTRON_EXTERNAL_INTERFACE "" "eth2"
    
    # Provider networks
    echo ""
    echo -e "${CYAN}Configure provider networks (VLAN ranges)? (y/n):${NC}"
    read -r configure_vlans
    if [[ "$configure_vlans" =~ ^[Yy] ]]; then
        read_input "Provider network VLAN range (e.g., 100:200)" VLAN_RANGE "" "100:200"
        CONFIGURE_PROVIDER_NETWORKS=true
    else
        CONFIGURE_PROVIDER_NETWORKS=false
        VLAN_RANGE=""
    fi
    
    success_message "Network configuration collected"
    update_step 3 "COMPLETED"
}

# Step 5: Storage Configuration
step_storage_configuration() {
    update_step 4 "IN_PROGRESS"
    show_progress
    
    echo -e "${WHITE}${BOLD}=== Storage Configuration ===${NC}"
    echo ""
    
    if [[ "$DEPLOY_CEPH" == true ]]; then
        info_message "Configuring Ceph storage..."
        
        # Collect Ceph configuration
        read_input "Ceph public network (CIDR)" CEPH_PUBLIC_NETWORK "" "$MANAGEMENT_SUBNET"
        read_input "Ceph cluster network (CIDR)" CEPH_CLUSTER_NETWORK "" "$MANAGEMENT_SUBNET"
        
        # OSD configuration
        echo ""
        echo -e "${CYAN}Ceph OSD disk configuration:${NC}"
        echo "1) Dedicated disks (recommended)"
        echo "2) Directory-based (for testing)"
        read_input "Choose OSD type (1 or 2)" OSD_TYPE validate_positive_number "1"
        
        if [[ "$OSD_TYPE" == "1" ]]; then
            read_input "OSD disk device (e.g., /dev/sdb)" OSD_DEVICE "" "/dev/sdb"
            
            # Validate OSD devices on storage nodes
            info_message "Validating OSD devices on storage nodes..."
            # This will be implemented in the validation step
        else
            read_input "OSD directory path" OSD_DIRECTORY "" "/var/lib/ceph/osd"
        fi
        
        # Pool configuration
        read_input "Ceph pool size (replicas)" CEPH_POOL_SIZE validate_positive_number "3"
        read_input "Ceph pool min size" CEPH_POOL_MIN_SIZE validate_positive_number "2"
        
    else
        info_message "Configuring LVM storage..."
        read_input "Cinder volume group name" CINDER_VOLUME_GROUP "" "cinder-volumes"
        read_input "LVM device for Cinder (e.g., /dev/sdb)" LVM_DEVICE "" "/dev/sdb"
    fi
    
    success_message "Storage configuration collected"
    update_step 4 "COMPLETED"
}

# Step 6: OpenStack Configuration
step_openstack_configuration() {
    update_step 5 "IN_PROGRESS"
    show_progress
    
    echo -e "${WHITE}${BOLD}=== OpenStack Services Configuration ===${NC}"
    echo ""
    
    # Core services (always enabled)
    info_message "Core services will be enabled: Keystone, Glance, Nova, Neutron, Horizon"
    
    # Optional services
    echo ""
    echo -e "${CYAN}Enable additional services:${NC}"
    
    echo -ne "${CYAN}Enable Cinder (Block Storage)? (Y/n): ${NC}"
    read -r enable_cinder
    ENABLE_CINDER="${enable_cinder:-y}"
    
    echo -ne "${CYAN}Enable Heat (Orchestration)? (Y/n): ${NC}"
    read -r enable_heat
    ENABLE_HEAT="${enable_heat:-y}"
    
    echo -ne "${CYAN}Enable Swift (Object Storage)? (y/N): ${NC}"
    read -r enable_swift
    ENABLE_SWIFT="${enable_swift:-n}"
    
    echo -ne "${CYAN}Enable Octavia (Load Balancer)? (y/N): ${NC}"
    read -r enable_octavia
    ENABLE_OCTAVIA="${enable_octavia:-n}"
    
    echo -ne "${CYAN}Enable Barbican (Key Manager)? (y/N): ${NC}"
    read -r enable_barbican
    ENABLE_BARBICAN="${enable_barbican:-n}"
    
    echo -ne "${CYAN}Enable Ironic (Bare Metal)? (y/N): ${NC}"
    read -r enable_ironic
    ENABLE_IRONIC="${enable_ironic:-n}"
    
    # Monitoring
    echo ""
    echo -ne "${CYAN}Enable monitoring (Prometheus, Grafana)? (Y/n): ${NC}"
    read -r enable_monitoring
    ENABLE_MONITORING="${enable_monitoring:-y}"
    
    # Logging
    echo -ne "${CYAN}Enable centralized logging (OpenSearch)? (Y/n): ${NC}"
    read -r enable_logging
    ENABLE_LOGGING="${enable_logging:-y}"
    
    success_message "OpenStack configuration collected"
    update_step 5 "COMPLETED"
}

# Main execution
main() {
    print_banner
    
    # Check if resuming from previous run
    if [[ -f "$CONFIG_DIR/deployment.state" ]]; then
        echo -e "${YELLOW}Previous deployment state found. Resume? (y/n):${NC}"
        read -r resume
        if [[ "$resume" =~ ^[Yy] ]]; then
            source "$CONFIG_DIR/deployment.state"
            info_message "Resuming from previous state..."
        else
            rm -f "$CONFIG_DIR/deployment.state"
        fi
    fi
    
    # Execute steps
    step_environment_setup
    step_collect_user_info
    step_node_discovery
    step_network_configuration
    step_storage_configuration
    step_openstack_configuration
    
    # Save state
    save_deployment_state
    
    echo ""
    echo -e "${GREEN}${BOLD}Configuration collection completed!${NC}"
    echo -e "${CYAN}Next: Run './install.sh --deploy' to start deployment${NC}"
}

# Save deployment state
save_deployment_state() {
    cat > "$CONFIG_DIR/deployment.state" <<EOF
# Deployment State - Generated by Kollaa Fleet Installer
DEPLOYMENT_NAME="$DEPLOYMENT_NAME"
OPENSTACK_RELEASE="$OPENSTACK_RELEASE"
KOLLA_BASE_DISTRO="$KOLLA_BASE_DISTRO"
CONTROLLER_COUNT="$CONTROLLER_COUNT"
COMPUTE_COUNT="$COMPUTE_COUNT"
STORAGE_COUNT="$STORAGE_COUNT"
DEPLOY_CEPH="$DEPLOY_CEPH"
AUTH_METHOD="$AUTH_METHOD"
SSH_KEY_PATH="$SSH_KEY_PATH"
SSH_USER="$SSH_USER"
MANAGEMENT_INTERFACE="$MANAGEMENT_INTERFACE"
EXTERNAL_INTERFACE="$EXTERNAL_INTERFACE"
INTERNAL_VIP="$INTERNAL_VIP"
EXTERNAL_VIP="$EXTERNAL_VIP"
EOF
}

# Help function
show_help() {
    echo "Kollaa Fleet Installer"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --help        Show this help message"
    echo "  --deploy      Start deployment with existing configuration"
    echo "  --validate    Validate current configuration"
    echo "  --cleanup     Clean up deployment"
    echo ""
}

# Node gathering functions
gather_node_info() {
    local node_ip="$1"
    local node_type="$2"
    
    info_message "Gathering information from $node_type node: $node_ip"
    
    # Create temporary script for node information gathering
    cat > /tmp/node_info.sh <<'EOF'
#!/bin/bash
echo "=== SYSTEM INFO ==="
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo ""
echo "=== MEMORY ==="
free -h
echo ""
echo "=== DISK SPACE ==="
df -h
echo ""
echo "=== NETWORK INTERFACES ==="
ip addr show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' '
echo ""
echo "=== NETWORK DETAILS ==="
for iface in $(ip addr show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' '); do
    echo "Interface: $iface"
    ethtool "$iface" 2>/dev/null | grep -E "Speed|Duplex" || echo "  Speed: Unknown"
    ip addr show "$iface" | grep -E "inet |inet6 " || true
    echo ""
done
echo "=== STORAGE DEVICES ==="
lsblk -d | grep -v "loop\|sr"
echo ""
echo "=== CEPH STORAGE CHECK ==="
for disk in /dev/sd{b..z}; do
    if [[ -b "$disk" ]]; then
        echo "$disk: $(lsblk -o SIZE -n -d $disk 2>/dev/null || echo 'Unknown size')"
    fi
done
EOF
    
    # Execute on remote node
    scp /tmp/node_info.sh "$SSH_USER@$node_ip:/tmp/"
    ssh "$SSH_USER@$node_ip" "chmod +x /tmp/node_info.sh && /tmp/node_info.sh" | \
        tee "$CONFIG_DIR/node_info_${node_ip}.txt"
    
    # Clean up
    ssh "$SSH_USER@$node_ip" "rm -f /tmp/node_info.sh"
    rm -f /tmp/node_info.sh
}

# Validation functions with fixes
validate_network_config() {
    local network="$1"
    if [[ $network =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 0
    else
        echo -e "${RED}Invalid network format (use CIDR notation, e.g., 192.168.1.0/24)${NC}"
        return 1
    fi
}

validate_vlan_range() {
    local range="$1"
    if [[ $range =~ ^[0-9]+:[0-9]+$ ]]; then
        local start=$(echo "$range" | cut -d: -f1)
        local end=$(echo "$range" | cut -d: -f2)
        if [[ $start -lt $end && $start -ge 1 && $end -le 4094 ]]; then
            return 0
        fi
    fi
    echo -e "${RED}Invalid VLAN range (use format: start:end, e.g., 100:200)${NC}"
    return 1
}

# Updated network configuration step
step_network_configuration() {
    update_step 3 "IN_PROGRESS"
    show_progress
    
    echo -e "${WHITE}${BOLD}=== Network Configuration ===${NC}"
    echo ""
    
    # Management network
    read_input "Management network interface" MANAGEMENT_INTERFACE "" "eth0"
    read_input "Management network subnet (CIDR)" MANAGEMENT_SUBNET validate_network_config "10.0.0.0/24"
    read_input "Management network gateway" MANAGEMENT_GATEWAY validate_ip "10.0.0.1"
    
    # API networks
    read_input "Internal API network interface" API_INTERFACE "" "$MANAGEMENT_INTERFACE"
    read_input "Internal VIP address" INTERNAL_VIP validate_ip "10.0.0.10"
    
    # External network
    read_input "External network interface" EXTERNAL_INTERFACE "" "eth1"
    read_input "External VIP address" EXTERNAL_VIP validate_ip
    read_input "Public API subnet (CIDR)" PUBLIC_SUBNET validate_network_config "192.168.1.0/24"
    
    # Tunnel network
    read_input "Tunnel network interface" TUNNEL_INTERFACE "" "$MANAGEMENT_INTERFACE"
    
    # Neutron external interface
    read_input "Neutron external interface (for floating IPs)" NEUTRON_EXTERNAL_INTERFACE "" "eth2"
    
    # Provider networks
    echo ""
    echo -e "${CYAN}Configure provider networks (VLAN ranges)? (y/n):${NC}"
    read -r configure_vlans
    if [[ "$configure_vlans" =~ ^[Yy] ]]; then
        read_input "Provider network VLAN range (e.g., 100:200)" VLAN_RANGE validate_vlan_range "100:200"
        CONFIGURE_PROVIDER_NETWORKS=true
    else
        CONFIGURE_PROVIDER_NETWORKS=false
        VLAN_RANGE=""
    fi
    
    success_message "Network configuration collected"
    update_step 3 "COMPLETED"
}

# Updated node discovery with information gathering
step_node_discovery() {
    update_step 2 "IN_PROGRESS"
    show_progress
    
    echo -e "${WHITE}${BOLD}=== Node Discovery ===${NC}"
    echo ""
    
    declare -a CONTROLLER_IPS=()
    declare -a COMPUTE_IPS=()
    declare -a STORAGE_IPS=()
    
    # Collect controller IPs
    info_message "Collecting controller node IPs..."
    for i in $(seq 1 "$CONTROLLER_COUNT"); do
        read_input "Controller $i IP address" controller_ip validate_ip
        CONTROLLER_IPS+=("$controller_ip")
    done
    
    # Collect compute IPs
    info_message "Collecting compute node IPs..."
    for i in $(seq 1 "$COMPUTE_COUNT"); do
        read_input "Compute $i IP address" compute_ip validate_ip
        COMPUTE_IPS+=("$compute_ip")
    done
    
    # Collect storage IPs if needed
    if [[ "$DEPLOY_CEPH" == true ]]; then
        info_message "Collecting storage node IPs..."
        for i in $(seq 1 "$STORAGE_COUNT"); do
            read_input "Storage $i IP address" storage_ip validate_ip
            STORAGE_IPS+=("$storage_ip")
        done
    fi
    
    # Test connectivity to all nodes
    info_message "Testing connectivity to all nodes..."
    
    local all_ips=("${CONTROLLER_IPS[@]}" "${COMPUTE_IPS[@]}")
    if [[ "$DEPLOY_CEPH" == true ]]; then
        all_ips+=("${STORAGE_IPS[@]}")
    fi
    
    for ip in "${all_ips[@]}"; do
        if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
            success_message "Node $ip is reachable"
        else
            error_exit "Node $ip is not reachable"
        fi
    done
    
    # Gather detailed information from nodes if SSH is available
    echo ""
    echo -e "${CYAN}Gather detailed node information? (recommended) (y/n):${NC}"
    read -r gather_info
    if [[ "$gather_info" =~ ^[Yy] ]]; then
        info_message "Gathering detailed information from all nodes..."
        
        # Test SSH first
        for ip in "${all_ips[@]}"; do
            if [[ "$AUTH_METHOD" == "1" ]]; then
                if ssh -o ConnectTimeout=5 -i "$SSH_KEY_PATH" "$SSH_USER@$ip" "exit" 2>/dev/null; then
                    gather_node_info "$ip" "node"
                else
                    warning_message "Cannot SSH to $ip - skipping detailed info gathering"
                fi
            fi
        done
    fi
    
    success_message "All nodes are reachable"
    update_step 2 "COMPLETED"
}

# Parse command line arguments
case "${1:-}" in
    --help)
        show_help
        exit 0
        ;;
    --deploy)
        if [[ -f "$SCRIPT_DIR/install-deploy.sh" ]]; then
            source "$SCRIPT_DIR/install-deploy.sh"
            deploy_main
        else
            error_exit "Deployment module not found"
        fi
        ;;
    --validate)
        echo "Running validation..."
        if [[ -f "$CONFIG_DIR/deployment.state" ]]; then
            source "$CONFIG_DIR/deployment.state"
            echo "Validating configuration for deployment: $DEPLOYMENT_NAME"
            # Add validation logic here
        else
            error_exit "No deployment configuration found"
        fi
        ;;
    --cleanup)
        echo "Cleaning up deployment..."
        read -p "Are you sure you want to clean up the deployment? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            rm -rf "$CONFIG_DIR"
            info_message "Deployment configuration cleaned up"
        fi
        ;;
    *)
        main "$@"
        ;;
esac