#!/bin/bash
# Pre-deployment validation script for Kolla-Ansible

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INVENTORY=${1:-"inventories/multinode.yml"}
MIN_MEMORY_GB=8
MIN_DISK_GB=40
REQUIRED_INTERFACES=2

echo "=========================================="
echo "Kolla-Ansible Pre-deployment Check"
echo "=========================================="
echo ""

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}Warning: This script should be run as root or with sudo for complete validation${NC}"
fi

# Check if inventory file exists
if [[ ! -f "$INVENTORY" ]]; then
    echo -e "${RED}Error: Inventory file not found: $INVENTORY${NC}"
    exit 1
fi

echo "Using inventory: $INVENTORY"
echo ""

# Function to check command existence
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
        return 0
    fi
}

# Function to check Python module
check_python_module() {
    if python3 -c "import $1" &> /dev/null; then
        echo -e "${GREEN}✓ Python module $1 is installed${NC}"
        return 0
    else
        echo -e "${RED}Error: Python module $1 is not installed${NC}"
        return 1
    fi
}

# Function to validate host connectivity
check_host_connectivity() {
    local host=$1
    if ping -c 1 -W 2 "$host" &> /dev/null; then
        echo -e "${GREEN}✓ Host $host is reachable${NC}"
        return 0
    else
        echo -e "${RED}Error: Host $host is not reachable${NC}"
        return 1
    fi
}

# Function to check host resources via SSH
check_host_resources() {
    local host=$1
    local user=$2
    
    echo ""
    echo "Checking resources on $host..."
    
    # Check memory
    local memory_kb=$(ssh -o StrictHostKeyChecking=no "$user@$host" "grep MemTotal /proc/meminfo | awk '{print \$2}'" 2>/dev/null)
    if [[ -n "$memory_kb" ]]; then
        local memory_gb=$((memory_kb / 1024 / 1024))
        if [[ $memory_gb -ge $MIN_MEMORY_GB ]]; then
            echo -e "${GREEN}  ✓ Memory: ${memory_gb}GB (minimum: ${MIN_MEMORY_GB}GB)${NC}"
        else
            echo -e "${RED}  ✗ Memory: ${memory_gb}GB (minimum: ${MIN_MEMORY_GB}GB required)${NC}"
        fi
    fi
    
    # Check disk space
    local disk_gb=$(ssh -o StrictHostKeyChecking=no "$user@$host" "df -BG / | tail -1 | awk '{print \$4}' | sed 's/G//'" 2>/dev/null)
    if [[ -n "$disk_gb" ]]; then
        if [[ $disk_gb -ge $MIN_DISK_GB ]]; then
            echo -e "${GREEN}  ✓ Disk space: ${disk_gb}GB free (minimum: ${MIN_DISK_GB}GB)${NC}"
        else
            echo -e "${RED}  ✗ Disk space: ${disk_gb}GB free (minimum: ${MIN_DISK_GB}GB required)${NC}"
        fi
    fi
    
    # Check network interfaces
    local iface_count=$(ssh -o StrictHostKeyChecking=no "$user@$host" "ip link show | grep -c '^[0-9]' | grep -v lo" 2>/dev/null || echo 0)
    if [[ $iface_count -ge $REQUIRED_INTERFACES ]]; then
        echo -e "${GREEN}  ✓ Network interfaces: $iface_count (minimum: $REQUIRED_INTERFACES)${NC}"
    else
        echo -e "${YELLOW}  ! Network interfaces: $iface_count (recommended: $REQUIRED_INTERFACES)${NC}"
    fi
}

echo "1. Checking local environment..."
echo "================================"

# Check required commands
check_command ansible
check_command ansible-playbook
check_command python3
check_command pip3
check_command docker || echo -e "${YELLOW}  Note: Docker will be installed by bootstrap-servers${NC}"

echo ""

# Check Python modules
echo "2. Checking Python dependencies..."
echo "=================================="
check_python_module ansible
check_python_module jinja2
check_python_module netaddr
check_python_module docker || echo -e "${YELLOW}  Note: Install with: pip3 install docker${NC}"

echo ""

# Check Kolla-Ansible installation
echo "3. Checking Kolla-Ansible..."
echo "============================="
if command -v kolla-ansible &> /dev/null; then
    echo -e "${GREEN}✓ Kolla-Ansible is installed${NC}"
    kolla-ansible --version
else
    echo -e "${RED}Error: Kolla-Ansible is not installed${NC}"
    echo "Install with: pip3 install kolla-ansible"
fi

echo ""

# Parse inventory and check hosts
echo "4. Checking inventory hosts..."
echo "=============================="

# Extract unique hosts from inventory
hosts=$(ansible-inventory -i "$INVENTORY" --list 2>/dev/null | jq -r '._meta.hostvars | keys[]' | grep -v localhost | sort -u)

if [[ -z "$hosts" ]]; then
    echo -e "${YELLOW}Warning: No remote hosts found in inventory${NC}"
else
    for host_entry in $hosts; do
        # Get host details from inventory
        host_info=$(ansible-inventory -i "$INVENTORY" --host "$host_entry" 2>/dev/null)
        ansible_host=$(echo "$host_info" | jq -r '.ansible_host // empty')
        ansible_user=$(echo "$host_info" | jq -r '.ansible_user // "root"')
        
        if [[ -n "$ansible_host" ]]; then
            echo ""
            echo "Checking $host_entry ($ansible_host)..."
            check_host_connectivity "$ansible_host"
            
            # Try to check resources if we have SSH access
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$ansible_user@$ansible_host" "exit" &>/dev/null; then
                check_host_resources "$ansible_host" "$ansible_user"
            else
                echo -e "${YELLOW}  ! Cannot SSH to host (check SSH keys and user)${NC}"
            fi
        fi
    done
fi

echo ""

# Check for globals.yml
echo "5. Checking configuration files..."
echo "=================================="
for env in production staging dev; do
    if [[ -f "environments/$env/globals.yml" ]]; then
        echo -e "${GREEN}✓ Found globals.yml for $env environment${NC}"
    fi
done

echo ""

# Final summary
echo "=========================================="
echo "Pre-deployment Check Summary"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Fix any errors (RED) shown above"
echo "2. Review warnings (YELLOW) and address if needed"
echo "3. Ensure SSH key authentication is set up for all hosts"
echo "4. Configure your globals.yml file"
echo "5. Run: kolla-ansible -i $INVENTORY bootstrap-servers"
echo ""