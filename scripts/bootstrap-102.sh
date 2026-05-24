#!/usr/bin/env bash
# =============================================================================
# Proxmox Host Bootstrap Script for Container 102
# =============================================================================
# Run this ONCE on your Proxmox host (root@workstation) to fully set up
# Minecraft inside container 102.
#
# Usage:
#   ssh root@workstation
#   bash /dev/stdin << 'REMOTE_EOF'
#   # paste this entire script
#   REMOTE_EOF
#
# Or save to file:
#   wget -O bootstrap-102.sh https://raw.githubusercontent.com/rifaterdemsahin/minecraft/main/scripts/bootstrap-102.sh
#   bash bootstrap-102.sh
# =============================================================================

set -euo pipefail

CTID=102
IP=192.168.0.236

log() { echo -e "\033[0;32m[BOOTSTRAP]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARNING]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }

# =============================================================================
# Step 1: Verify container is running
# =============================================================================
log "Checking container ${CTID} status..."
if ! pct status "${CTID}" | grep -q "status: running"; then
    error "Container ${CTID} is not running. Start it first: pct start ${CTID}"
    exit 1
fi

# =============================================================================
# Step 2: Install missing tools inside container
# =============================================================================
log "Installing curl, wget, jq, git, ufw, screen inside container..."
pct exec "${CTID}" -- bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl wget jq git ufw screen htop net-tools
' || {
    error "Failed to install packages. Check network connectivity inside container."
    exit 1
}

# =============================================================================
# Step 3: Push install script into container
# =============================================================================
log "Pushing install-minecraft.sh into container..."

# Create the install script inline and push it
pct exec "${CTID}" -- bash -c '
mkdir -p /opt/minecraft/scripts
cat > /opt/minecraft/scripts/install-minecraft.sh << "INSTALLER_EOF"
#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.21.4}"
SERVER_TYPE="${2:-Paper}"
INSTALL_DIR="/opt/minecraft"
SERVICE_USER="minecraft"
SERVICE_GROUP="minecraft"

log_info()  { echo -e "\033[0;32m[INFO]\033[0m  $*"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_step()  { echo -e "\033[0;34m[STEP]\033[0m  $*"; }

log_step "Pre-flight checks..."

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root."
    exit 1
fi

if ! command -v curl >/dev/null || ! command -v wget >/dev/null || ! command -v jq >/dev/null; then
    log_warn "Installing required tools..."
    apt-get update -qq
    apt-get install -y -qq curl wget jq
fi

if ! java -version 2>&1 | grep -q "openjdk version \"21"; then
    log_warn "Java 21 not detected. Installing..."
    apt-get update -qq
    apt-get install -y -qq openjdk-21-jre-headless
fi

if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${SERVICE_USER}"
    log_info "Created user: ${SERVICE_USER}"
fi

mkdir -p "${INSTALL_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

log_step "Downloading ${SERVER_TYPE} server v${VERSION}..."

BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${VERSION}/builds" | \
    jq -r ".builds | map(select(.channel == \"default\")) | last | .build")

if [[ -z "${BUILD}" || "${BUILD}" == "null" ]]; then
    log_error "Could not find Paper build for version ${VERSION}."
    exit 1
fi

DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/${VERSION}/builds/${BUILD}/downloads/paper-${VERSION}-${BUILD}.jar"
log_info "Downloading Paper build ${BUILD}..."
wget -q --show-progress -O server.jar "${DOWNLOAD_URL}"

chown "${SERVICE_USER}:${SERVICE_GROUP}" server.jar

log_step "Generating server configuration..."

cat > "${INSTALL_DIR}/server.properties" << "CONFIG_EOF"
server-port=25565
motd=A Minecraft Server
max-players=20
online-mode=true
gamemode=survival
difficulty=easy
view-distance=10
simulation-distance=10
enable-rcon=false
white-list=false
spawn-protection=16
CONFIG_EOF

cat > "${INSTALL_DIR}/eula.txt" << "EULA_EOF"
#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
eula=true
EULA_EOF

cat > "${INSTALL_DIR}/ops.json" << "OPS_EOF"
[]
OPS_EOF

cat > "${INSTALL_DIR}/whitelist.json" << "WL_EOF"
[]
WL_EOF

chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}"

log_step "Creating systemd service..."

TOTAL_MEM_MB=$(free -m | awk "/^Mem:/{print \$2}")
HEAP_MB=$((TOTAL_MEM_MB - 1024))
if [[ ${HEAP_MB} -lt 1024 ]]; then HEAP_MB=1024; fi
HEAP_G=$(( (HEAP_MB + 1023) / 1024 ))

cat > /etc/systemd/system/minecraft.service << "SERVICE_EOF"
[Unit]
Description=Minecraft Paper Server
After=network.target

[Service]
Type=simple
User=minecraft
Group=minecraft
WorkingDirectory=/opt/minecraft
ExecStart=/usr/bin/java -Xms${HEAP_G}G -Xmx${HEAP_G}G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=100 -XX:+DisableExplicitGC -XX:TargetSurvivorRatio=90 -XX:G1NewSizePercent=50 -XX:G1MaxNewSizePercent=80 -XX:G1MixedGCLiveThresholdPercent=50 -XX:+AlwaysPreTouch -jar server.jar nogui
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable minecraft.service

log_step "Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 25565/tcp comment "Minecraft Server" 2>/dev/null || true
    ufw allow 25575/tcp comment "Minecraft RCON" 2>/dev/null || true
    ufw reload 2>/dev/null || true
fi

mkdir -p "${INSTALL_DIR}/logs"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}/logs"

echo ""
echo "========================================"
echo "  Minecraft Server Installed!"
echo "========================================"
echo "  Version:     ${VERSION}"
echo "  Type:        ${SERVER_TYPE}"
echo "  Directory:   ${INSTALL_DIR}"
echo "  JVM Heap:    ${HEAP_G}G"
echo ""
echo "  Commands:"
echo "  Start:   systemctl start minecraft"
echo "  Stop:    systemctl stop minecraft"
echo "  Status:  systemctl status minecraft"
echo "  Logs:    journalctl -u minecraft -f"
echo "========================================"
INSTALLER_EOF

chmod +x /opt/minecraft/scripts/install-minecraft.sh
'

# =============================================================================
# Step 4: Run the installer inside container
# =============================================================================
log "Running Minecraft installer inside container..."
pct exec "${CTID}" -- bash /opt/minecraft/scripts/install-minecraft.sh 1.21.4 Paper

# =============================================================================
# Step 5: Start the server
# =============================================================================
log "Starting Minecraft server..."
pct exec "${CTID}" -- systemctl start minecraft

# =============================================================================
# Step 6: Wait for startup
# =============================================================================
log "Waiting for server to start (up to 60 seconds)..."
for i in {1..12}; do
    sleep 5
    if pct exec "${CTID}" -- bash -c 'journalctl -u minecraft --no-pager -n 5 2>/dev/null | grep -q "Done ("' 2>/dev/null; then
        log "Server started successfully!"
        break
    fi
    echo -n "."
done
echo ""

# =============================================================================
# Step 7: Verify
# =============================================================================
log "Running verification checks..."

# Check service status
if pct exec "${CTID}" -- systemctl is-active minecraft >/dev/null 2>&1; then
    log "✅ Service is ACTIVE"
else
    warn "⚠️  Service is NOT active. Checking logs..."
    pct exec "${CTID}" -- journalctl -u minecraft --no-pager -n 20
fi

# Check port
if pct exec "${CTID}" -- bash -c 'ss -tlnp | grep -q ":25565"' 2>/dev/null; then
    log "✅ Port 25565 is LISTENING"
else
    warn "⚠️  Port 25565 is NOT listening"
fi

# Check logs for startup completion
if pct exec "${CTID}" -- bash -c 'journalctl -u minecraft --no-pager -n 10 2>/dev/null | grep -q "Done ("' 2>/dev/null; then
    STARTUP_TIME=$(pct exec "${CTID}" -- bash -c 'journalctl -u minecraft --no-pager -n 10 2>/dev/null | grep "Done (" | tail -n1 | grep -oP "Done \(\K[^!]+"')
    log "✅ Server startup completed in ${STARTUP_TIME}"
else
    warn "⚠️  Server may still be starting or failed to start"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================"
echo "  Bootstrap Complete!"
echo "========================================"
echo "  Container:   ${CTID}"
echo "  IP Address:  ${IP}"
echo "  SSH:         ssh root@${IP}"
echo "  Minecraft:   ${IP}:25565"
echo ""
echo "  Check logs:  pct exec ${CTID} -- journalctl -u minecraft -f"
echo "  Console:     pct console ${CTID}"
echo "========================================"
