#!/bin/bash
# Network configuration script for OpenStack nodes

set -euo pipefail

# Configuration
MANAGEMENT_INTERFACE=${1:-eth0}
EXTERNAL_INTERFACE=${2:-eth1}
EXTERNAL_BRIDGE="br-ex"

echo "OpenStack Network Configuration"
echo "==============================="
echo "Management Interface: $MANAGEMENT_INTERFACE"
echo "External Interface: $EXTERNAL_INTERFACE"
echo ""

# Function to detect OS family
detect_os() {
    if [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

OS_FAMILY=$(detect_os)

# Create external bridge for Neutron
create_external_bridge() {
    echo "Creating external bridge $EXTERNAL_BRIDGE..."
    
    if [[ "$OS_FAMILY" == "redhat" ]]; then
        # For RHEL-based systems using NetworkManager
        if command -v nmcli &> /dev/null; then
            # Check if bridge already exists
            if ! nmcli connection show "$EXTERNAL_BRIDGE" &> /dev/null; then
                # Create bridge
                nmcli connection add type bridge \
                    con-name "$EXTERNAL_BRIDGE" \
                    ifname "$EXTERNAL_BRIDGE" \
                    autoconnect yes
                
                # Add external interface to bridge
                nmcli connection add type bridge-slave \
                    con-name "${EXTERNAL_BRIDGE}-${EXTERNAL_INTERFACE}" \
                    ifname "$EXTERNAL_INTERFACE" \
                    master "$EXTERNAL_BRIDGE" \
                    autoconnect yes
                
                # Bring up the bridge
                nmcli connection up "$EXTERNAL_BRIDGE"
                
                echo "Bridge $EXTERNAL_BRIDGE created successfully"
            else
                echo "Bridge $EXTERNAL_BRIDGE already exists"
            fi
        else
            # Fallback to traditional network scripts
            cat > "/etc/sysconfig/network-scripts/ifcfg-$EXTERNAL_BRIDGE" <<EOF
DEVICE=$EXTERNAL_BRIDGE
TYPE=Bridge
BOOTPROTO=none
ONBOOT=yes
NM_CONTROLLED=no
EOF
            
            # Update external interface config
            cat > "/etc/sysconfig/network-scripts/ifcfg-$EXTERNAL_INTERFACE" <<EOF
DEVICE=$EXTERNAL_INTERFACE
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
NM_CONTROLLED=no
BRIDGE=$EXTERNAL_BRIDGE
EOF
            
            # Restart network
            systemctl restart network || systemctl restart NetworkManager
        fi
        
    elif [[ "$OS_FAMILY" == "debian" ]]; then
        # For Debian-based systems
        # Check if using netplan
        if [[ -d /etc/netplan ]]; then
            cat > "/etc/netplan/99-openstack-bridges.yaml" <<EOF
network:
  version: 2
  renderer: networkd
  bridges:
    $EXTERNAL_BRIDGE:
      interfaces:
        - $EXTERNAL_INTERFACE
      dhcp4: no
      dhcp6: no
EOF
            netplan apply
            
        else
            # Traditional /etc/network/interfaces
            cat >> /etc/network/interfaces <<EOF

# OpenStack external bridge
auto $EXTERNAL_BRIDGE
iface $EXTERNAL_BRIDGE inet manual
    bridge_ports $EXTERNAL_INTERFACE
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
EOF
            
            # Bring up the bridge
            ifup "$EXTERNAL_BRIDGE"
        fi
        
        echo "Bridge $EXTERNAL_BRIDGE created successfully"
    else
        echo "Unsupported OS family: $OS_FAMILY"
        exit 1
    fi
}

# Configure kernel parameters for networking
configure_kernel_parameters() {
    echo "Configuring kernel parameters..."
    
    cat > /etc/sysctl.d/99-openstack-networking.conf <<EOF
# Enable IP forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Disable reverse path filtering (required for floating IPs)
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0

# Enable netfilter on bridges (required for security groups)
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-arptables = 1

# Increase ARP cache size for large deployments
net.ipv4.neigh.default.gc_thresh1 = 4096
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh3 = 16384
EOF
    
    # Load bridge module if not loaded
    modprobe br_netfilter || true
    
    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-openstack-networking.conf
}

# Disable firewall (will be managed by OpenStack)
disable_firewall() {
    echo "Configuring firewall..."
    
    if [[ "$OS_FAMILY" == "redhat" ]]; then
        if systemctl is-active firewalld &> /dev/null; then
            echo "Disabling firewalld (OpenStack will manage firewall rules)..."
            systemctl stop firewalld
            systemctl disable firewalld
        fi
    elif [[ "$OS_FAMILY" == "debian" ]]; then
        if systemctl is-active ufw &> /dev/null; then
            echo "Disabling ufw (OpenStack will manage firewall rules)..."
            ufw disable
        fi
    fi
}

# Main execution
echo "Starting network configuration..."

# Create external bridge
create_external_bridge

# Configure kernel parameters
configure_kernel_parameters

# Handle firewall
disable_firewall

echo ""
echo "Network configuration completed!"
echo ""
echo "Current bridge status:"
ip addr show "$EXTERNAL_BRIDGE"

echo ""
echo "Next steps:"
echo "1. Verify network connectivity"
echo "2. Update your globals.yml with correct interface names"
echo "3. Run kolla-ansible bootstrap-servers"