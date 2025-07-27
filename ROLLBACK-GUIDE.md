# 🔥 Kollaa Fleet Rollback Guide

## ⚠️ CRITICAL WARNING
**Rollback operations are IRREVERSIBLE and will DESTROY your OpenStack deployment!**

Always backup important data before proceeding.

## 🚀 Quick Rollback Commands

### Interactive Rollback (Recommended)
```bash
./deploy-openstack.sh --rollback
# or
./rollback.sh
```

### Command Line Options
```bash
# Complete nuclear destruction
./deploy-openstack.sh --nuclear

# Kolla-Ansible destroy only
./deploy-openstack.sh --kolla-destroy

# Clean remote nodes only
./deploy-openstack.sh --remote-clean

# Local configuration cleanup only
./deploy-openstack.sh --cleanup
```

## 🛡️ Safety Mechanisms

### Triple Confirmation System
1. Type: `I UNDERSTAND THE CONSEQUENCES`
2. Type: `DESTROY MY DEPLOYMENT`
3. Type: Your deployment name (e.g., `production`)

### Additional Safety Features
- ✅ 10-second countdown with abort option (Ctrl+C)
- ✅ Automatic backup creation before destruction
- ✅ Deployment name verification
- ✅ Color-coded warnings and confirmations

## 🧹 What Gets Destroyed

### On All Nodes
- 🐳 All Docker containers and images
- 📁 All OpenStack configuration files
- 🌐 Network bridges and interfaces
- 💾 LVM volumes and storage
- 🔧 Systemd services
- 📝 Log files and temporary data
- 👤 OpenStack user accounts

### Local Machine
- 🐍 Python virtual environment
- ⚙️ Deployment configuration
- 🔑 SSH known_hosts entries
- 📋 Inventory and globals files

## 🔄 Reboot Handling

### Why Reboot is Needed
Kolla-Ansible's destroy command doesn't always clean:
- Kernel modules (OVS, netfilter)
- Network namespaces
- Memory-resident processes
- Systemd lingering services

### Automated Reboot Options
The rollback system offers:
- ✅ Automatic reboot of all nodes
- ✅ Manual reboot instructions
- ✅ 1-minute delay for graceful shutdown

## 📋 Rollback Types

### 1. Nuclear Rollback (Complete)
```bash
./rollback.sh --nuclear
```
**What it does:**
- Runs Kolla-Ansible destroy
- Executes remote node cleanup
- Removes local configuration
- Offers automatic reboot

**Use when:** Complete fresh start needed

### 2. Kolla Destroy Only
```bash
./rollback.sh --kolla-destroy
```
**What it does:**
- Uses Kolla's built-in destroy
- Handles reboot recommendation

**Use when:** Standard Kolla cleanup sufficient

### 3. Remote Cleanup Only
```bash
./rollback.sh --remote-only
```
**What it does:**
- Nuclear cleanup on remote nodes only
- Preserves local configuration

**Use when:** Nodes need cleaning but keeping config

### 4. Local Cleanup Only
```bash
./rollback.sh --local-only
```
**What it does:**
- Removes only local files
- Leaves remote nodes untouched

**Use when:** Starting over with same nodes

## 🏥 Recovery After Rollback

### If Something Goes Wrong
1. **Check backup directory:**
   ```bash
   ls deployment-config/backup-*
   ```

2. **View rollback logs:**
   ```bash
   cat deployment-config/rollback.log
   ```

3. **Manual cleanup if needed:**
   ```bash
   # Remove remaining Docker items
   docker system prune -af --volumes
   
   # Clean network interfaces
   sudo ip link show | grep br- | sudo xargs -I {} ip link delete {}
   
   # Restart networking
   sudo systemctl restart networking  # or NetworkManager
   ```

### Starting Fresh After Rollback
1. **Verify clean state:**
   ```bash
   docker ps -a  # Should be empty
   sudo ovs-vsctl show  # Should show no bridges
   ```

2. **Optional: Reboot all nodes:**
   ```bash
   # For each node:
   ssh user@node-ip "sudo reboot"
   ```

3. **Start new deployment:**
   ```bash
   ./deploy-openstack.sh --configure
   ```

## 🎯 Best Practices

### Before Rollback
- ✅ Backup any important VM data
- ✅ Export any custom configurations
- ✅ Document any network customizations
- ✅ Test rollback in development first

### During Rollback
- ✅ Read all confirmations carefully
- ✅ Use Ctrl+C to abort if unsure
- ✅ Monitor the process for errors
- ✅ Keep terminal session open

### After Rollback
- ✅ Verify clean state on all nodes
- ✅ Reboot nodes for complete cleanup
- ✅ Check for any remaining processes
- ✅ Review logs for any issues

## 🆘 Emergency Contacts

If rollback fails or causes issues:

1. **Check logs:** `deployment-config/rollback.log`
2. **Review backups:** `deployment-config/backup-*/`
3. **Manual cleanup:** Refer to recovery section above
4. **Reboot nodes:** Often resolves lingering issues

---

**Remember:** Rollback is a nuclear option. When in doubt, backup first and test in development!

🔥 **"With great power comes great responsibility"** 🔥