#!/usr/bin/env bash
# =============================================================================
# Proxmox LXC Minecraft Server Setup
# =============================================================================
# Usage: ./scripts/proxmox-lxc-setup.sh [CTID] [HOSTNAME] [MEMORY_MB] [DISK_GB]
#   CTID       : Container ID (default: 9999)
#   HOSTNAME   : Container hostname (default: minecraft-server)
#   MEMORY_MB  : RAM in MB (default: 8192)
#   DISK_GB    : Disk size in GB (default: 32)
#
# Prerequisites (run on Proxmox host):
#   - Proxmox VE 7.x or 8.x
#   - Root or sudo access on Proxmox host
#   - Local storage available (or adjust STORAGE variable)
#
# Example:
#   ./scripts/proxmox-lxc-setup.sh 100 minecraft 8192 32
# =============================================================================

set -euo pipefail

# --- Load .env if present ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

# --- Configuration ---
CTID="${1:-${DEFAULT_CTID:-100}}"
HOSTNAME="${2:-${DEFAULT_HOSTNAME:-minecraft-server}}"
MEMORY_MB="${3:-${DEFAULT_MEMORY_MB:-8192}}"
DISK_GB="${4:-${DEFAULT_DISK_GB:-32}}"
STORAGE="local-lvm"           # Adjust to your Proxmox storage (local-lvm, local-zfs, etc.)
OS_TEMPLATE="ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
TEMPLATE_STORAGE="local"
ROOT_PASSWORD="$(openssl rand -base64 24)"
SSH_PORT="22"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# =============================================================================
# Pre-flight checks
# =============================================================================
log_info "Starting Proxmox LXC Minecraft setup..."
log_info "CTID: $CTID | Hostname: $HOSTNAME | RAM: ${MEMORY_MB}MB | Disk: ${DISK_GB}GB"

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root on the Proxmox host."
    exit 1
fi

if ! command -v pct &>/dev/null; then
    log_error "Proxmox Container Toolkit (pct) not found. Are you on a Proxmox host?"
    exit 1
fi

# Check if container ID already exists
if pct status "$CTID" &>/dev/null; then
    log_error "Container ID $CTID already exists. Remove it or choose another ID."
    exit 1
fi

# =============================================================================
# Download OS template if not present
# =============================================================================
log_info "Checking OS template availability..."
TEMPLATE_PATH="/var/lib/vz/template/cache/${OS_TEMPLATE}"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
    log_warn "Template not found locally. Attempting to download..."
    pveam update
    pveam download "$TEMPLATE_STORAGE" "$OS_TEMPLATE" || {
        log_error "Failed to download template. Check available templates with: pveam available"
        exit 1
    }
else
    log_info "Template already available."
fi

# =============================================================================
# Create the LXC container
# =============================================================================
log_info "Creating LXC container $CTID..."

pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${OS_TEMPLATE}" \
    --hostname "$HOSTNAME" \
    --storage "$STORAGE" \
    --rootfs "${STORAGE}:${DISK_GB}" \
    --memory "$MEMORY_MB" \
    --swap "${MEMORY_MB}" \
    --cores 4 \
    --cpuunits 1024 \
    --net0 "name=eth0,bridge=vmbr0,ip=dhcp,firewall=1" \
    --features "nesting=1" \
    --onboot 1 \
    --start 1 \
    --timezone host \
    --password "$ROOT_PASSWORD" || {
    log_error "Failed to create container."
    exit 1
}

# Wait for container to boot
log_info "Waiting for container to start..."
sleep 10

# Wait for network
for i in {1..30}; do
    IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -n "$IP" && "$IP" != *"hostname"* ]]; then
        break
    fi
    sleep 2
done

IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}')
if [[ -z "$IP" ]]; then
    log_warn "Could not detect container IP automatically. You may need to check manually."
    IP="<unknown>"
fi

# =============================================================================
# Container post-setup (inside LXC)
# =============================================================================
log_info "Configuring container $CTID..."

# Enable nesting features for Java
pct exec "$CTID" -- bash -c "
    apt-get update -qq && apt-get install -y -qq \
        curl wget jq git nano htop net-tools ufw \
        openjdk-21-jre-headless openjdk-21-jdk-headless \
        screen cron 2>/dev/null
    
    # Create minecraft user
    useradd -m -s /bin/bash minecraft 2>/dev/null || true
    
    # Create server directory
    mkdir -p /opt/minecraft
    chown -R minecraft:minecraft /opt/minecraft
    
    # UFW firewall rules
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ${SSH_PORT}/tcp
    ufw allow 25565/tcp
    ufw allow 25575/tcp
    ufw --force enable
"

# =============================================================================
# Setup systemd service
# =============================================================================
log_info "Installing Minecraft systemd service..."

pct exec "$CTID" -- bash -c "cat > /etc/systemd/system/minecraft.service << 'EOF'
[Unit]
Description=Minecraft Server
After=network.target

[Service]
Type=simple
User=minecraft
Group=minecraft
WorkingDirectory=/opt/minecraft
ExecStart=/usr/bin/java -Xms6G -Xmx6G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=100 -XX:+DisableExplicitGC -XX:TargetSurvivorRatio=90 -XX:G1NewSizePercent=50 -XX:G1MaxNewSizePercent=80 -XX:G1MixedGCLiveThresholdPercent=50 -XX:+AlwaysPreTouch -jar server.jar nogui
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable minecraft.service
"

# =============================================================================
# Copy install & test scripts into container
# =============================================================================
log_info "Copying management scripts into container..."

# Create scripts directory in container
pct exec "$CTID" -- mkdir -p /opt/minecraft/scripts

# Push scripts (will be done via file copy or we provide manual steps)
log_info "Scripts will need to be placed in /opt/minecraft/scripts after cloning repo."

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================"
echo "  LXC Container Created Successfully!"
echo "========================================"
echo "  CTID:        $CTID"
echo "  Hostname:    $HOSTNAME"
echo "  IP Address:  $IP"
echo "  SSH Access:  ssh root@$IP"
echo "  Root Pass:   $ROOT_PASSWORD"
echo "  RAM:         ${MEMORY_MB}MB"
echo "  Disk:        ${DISK_GB}GB"
echo ""
echo "  Proxmox Host: ${PROXMOX_HOST:-proxmox.rifaterdemsahin.com}"
echo "  Proxmox User: ${PROXMOX_USERNAME:-root}"
echo ""
echo "  Next Steps:"
echo "  1. SSH into the container: ssh root@$IP"
echo "  2. Clone this repo: git clone git@github.com:rifaterdemsahin/minecraft.git /opt/minecraft/scripts"
echo "  3. Run: cd /opt/minecraft/scripts && ./install-minecraft.sh"
echo "  4. Run: ./test-minecraft.sh to validate"
echo "========================================"
echo ""

# Save credentials to a file for reference
cat > "proxmox-credentials-${CTID}.txt" << EOF
Container ID: $CTID
Hostname:     $HOSTNAME
IP Address:   $IP
Root Password: $ROOT_PASSWORD
SSH Command:  ssh root@$IP
EOF

# Also save to keyvault if available
if command -v secret-tool &>/dev/null || command -v security &>/dev/null; then
    log_info "Saving credentials to system keyvault..."
    # macOS Keychain
    if command -v security &>/dev/null; then
        security add-generic-password -s "proxmox-minecraft-${CTID}" -a "root" -w "$ROOT_PASSWORD" -U 2>/dev/null || true
    fi
    # Linux Secret Service
    if command -v secret-tool &>/dev/null; then
        echo "$ROOT_PASSWORD" | secret-tool store --label="Proxmox Minecraft ${CTID}" service proxmox-minecraft username root 2>/dev/null || true
    fi
fi

log_info "Credentials saved to: proxmox-credentials-${CTID}.txt"
