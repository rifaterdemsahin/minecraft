#!/usr/bin/env bash
# =============================================================================
# Minecraft Server Installation Script (No-Git Fallback)
# =============================================================================
# This script installs and configures the Minecraft Java server.
# Run this INSIDE the Proxmox LXC container (or any Debian/Ubuntu VM).
#
# Usage:
#   ./scripts/install-minecraft.sh [VERSION] [SERVER_TYPE]
#
# Arguments:
#   VERSION     : Minecraft version (default: 1.21.4)
#   SERVER_TYPE : Paper | Vanilla | Forge | Fabric (default: Paper)
#
# Example:
#   ./install-minecraft.sh 1.21.4 Paper
# =============================================================================

set -euo pipefail

# --- Configuration ---
# Auto-detect latest Paper version if not specified
LATEST_PAPER_VERSION=$(curl -s "https://api.papermc.io/v2/projects/paper" | jq -r '.versions | last')
VERSION="${1:-${LATEST_PAPER_VERSION}}"
SERVER_TYPE="${2:-Paper}"
INSTALL_DIR="/opt/minecraft"
SERVICE_USER="minecraft"
SERVICE_GROUP="minecraft"
EULA_ACCEPT="true"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }

# =============================================================================
# Pre-flight Checks
# =============================================================================
log_step "Pre-flight checks..."

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (or with sudo)."
    exit 1
fi

# Ensure required tools are installed
if ! command -v curl &>/dev/null || ! command -v wget &>/dev/null || ! command -v jq &>/dev/null; then
    log_warn "Installing required tools (curl, wget, jq)..."
    apt-get update -qq
    apt-get install -y -qq curl wget jq
fi

# Ensure Java 21 is installed
if ! java -version 2>&1 | grep -q "openjdk version \"21"; then
    log_warn "Java 21 not detected. Installing..."
    apt-get update -qq
    apt-get install -y -qq openjdk-21-jre-headless openjdk-21-jdk-headless
fi

JAVA_VERSION=$(java -version 2>&1 | head -n1 | cut -d'"' -f2)
log_info "Java version: $JAVA_VERSION"

# Ensure service user exists
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$SERVICE_USER"
    log_info "Created user: $SERVICE_USER"
fi

# Create install directory
mkdir -p "$INSTALL_DIR"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# =============================================================================
# Download Server JAR
# =============================================================================
log_step "Downloading ${SERVER_TYPE} server v${VERSION}..."

download_paper() {
    local version=$1
    log_info "Fetching Paper build info for ${version}..."
    
    # Check if version exists
    local available_versions
    available_versions=$(curl -s "https://api.papermc.io/v2/projects/paper" | jq -r '.versions[]')
    if ! echo "$available_versions" | grep -q "^${version}$"; then
        log_error "Version ${version} not found in Paper builds."
        log_info "Available versions:"
        echo "$available_versions" | tail -n 5 | sed 's/^/  - /'
        log_info "Run with latest version: ./install-minecraft.sh ${LATEST_PAPER_VERSION} Paper"
        exit 1
    fi
    
    BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${version}/builds" | \
        jq -r '.builds | map(select(.channel == "default")) | last | .build')
    
    if [[ -z "$BUILD" || "$BUILD" == "null" ]]; then
        log_error "Could not find Paper build for version ${version}."
        log_info "Run with latest version: ./install-minecraft.sh ${LATEST_PAPER_VERSION} Paper"
        exit 1
    fi
    
    DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/${version}/builds/${BUILD}/downloads/paper-${version}-${BUILD}.jar"
    log_info "Downloading Paper build ${BUILD}..."
    wget -q --show-progress -O server.jar.new "$DOWNLOAD_URL"
}

download_vanilla() {
    local version=$1
    log_info "Fetching Vanilla manifest..."
    
    MANIFEST=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json)
    URL=$(echo "$MANIFEST" | jq -r --arg v "$version" '.versions[] | select(.id == $v) | .url')
    
    if [[ -z "$URL" || "$URL" == "null" ]]; then
        log_error "Version ${version} not found in Mojang manifest."
        exit 1
    fi
    
    SERVER_URL=$(curl -s "$URL" | jq -r '.downloads.server.url')
    log_info "Downloading Vanilla server..."
    wget -q --show-progress -O server.jar.new "$SERVER_URL"
}

download_forge() {
    local version=$1
    log_info "Forge installation requires additional steps. Installing recommended Forge..."
    log_warn "Forge installer may require interactive steps."
    
    FORGE_VERSION=$(curl -s "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json" | \
        jq -r --arg v "$version" '.promos | keys[] | select(startswith($v + "-"))')
    
    if [[ -z "$FORGE_VERSION" ]]; then
        log_error "Could not find Forge version for Minecraft ${version}."
        exit 1
    fi
    
    DOWNLOAD_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_VERSION}/forge-${FORGE_VERSION}-installer.jar"
    wget -q --show-progress -O forge-installer.jar "$DOWNLOAD_URL"
    java -jar forge-installer.jar --installServer
    mv "forge-${FORGE_VERSION}.jar" server.jar.new 2>/dev/null || \
        cp forge-*.jar server.jar.new
}

download_fabric() {
    local version=$1
    log_info "Downloading Fabric server..."
    
    INSTALLER_URL="https://meta.fabricmc.net/v2/versions/loader/${version}//server/jar"
    wget -q --show-progress -O server.jar.new "$INSTALLER_URL"
}

# Backup existing server.jar if present
if [[ -f server.jar ]]; then
    cp server.jar "server.jar.backup.$(date +%s)"
    log_warn "Existing server.jar backed up."
fi

# Download based on type
case "$SERVER_TYPE" in
    Paper|paper)
        download_paper "$VERSION"
        ;;
    Vanilla|vanilla)
        download_vanilla "$VERSION"
        ;;
    Forge|forge)
        download_forge "$VERSION"
        ;;
    Fabric|fabric)
        download_fabric "$VERSION"
        ;;
    *)
        log_error "Unknown server type: $SERVER_TYPE. Use Paper, Vanilla, Forge, or Fabric."
        exit 1
        ;;
esac

# Validate download
if [[ ! -f server.jar.new || ! -s server.jar.new ]]; then
    log_error "Download failed or file is empty."
    exit 1
fi

mv server.jar.new server.jar
chown "${SERVICE_USER}:${SERVICE_GROUP}" server.jar
log_info "Server JAR downloaded successfully."

# =============================================================================
# Configuration Files
# =============================================================================
log_step "Generating server configuration..."

# server.properties
cat > "${INSTALL_DIR}/server.properties" << 'EOF'
# Minecraft server properties
# Generated by install script
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=survival
enable-command-block=false
enable-query=false
generator-settings={}
enforce-secure-profile=true
level-name=world
motd=A Minecraft Server
query.port=25565
pvp=true
generate-structures=true
max-chained-neighbor-updates=1000000
difficulty=easy
network-compression-threshold=256
max-tick-time=60000
require-resource-pack=false
use-native-transport=true
max-players=20
online-mode=true
enable-status=true
allow-flight=false
initial-disabled-packs=
broadcast-rcon-to-ops=true
view-distance=10
server-ip=
resource-pack-prompt=
allow-nether=true
server-port=25565
enable-rcon=false
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=10
rcon.password=
player-idle-timeout=0
debug=false
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
spawn-animals=true
function-permission-level=2
initial-enabled-packs=vanilla
level-type=minecraft\:normal
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
spawn-protection=16
resource-pack-sha1=
max-world-size=29999984
EOF

# eula.txt
if [[ "$EULA_ACCEPT" == "true" ]]; then
    cat > "${INSTALL_DIR}/eula.txt" << 'EOF'
#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
#Sat Jan 01 00:00:00 UTC 2024
eula=true
EOF
    log_warn "Mojang EULA has been automatically accepted. If you do not agree, stop the server and set eula=false."
else
    cat > "${INSTALL_DIR}/eula.txt" << 'EOF'
#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
#Sat Jan 01 00:00:00 UTC 2024
eula=false
EOF
fi

# JVM args optimization file (reference)
cat > "${INSTALL_DIR}/jvm-args.txt" << 'EOF'
# Recommended JVM arguments for Paper/Modern Minecraft Servers
# Adjust -Xms and -Xmx based on available RAM

-Xms2G
-Xmx2G
-XX:+UseG1GC
-XX:+UnlockExperimentalVMOptions
-XX:MaxGCPauseMillis=100
-XX:+DisableExplicitGC
-XX:TargetSurvivorRatio=90
-XX:G1NewSizePercent=50
-XX:G1MaxNewSizePercent=80
-XX:G1MixedGCLiveThresholdPercent=50
-XX:+AlwaysPreTouch
-Dusing.aikars.flags=https://mcflags.emc.gs
-Daikars.new.flags=true
EOF

# ops.json template
cat > "${INSTALL_DIR}/ops.json" << 'EOF'
[
]
EOF

# whitelist.json template
cat > "${INSTALL_DIR}/whitelist.json" << 'EOF'
[
]
EOF

# Save install info for updates
cat > "${INSTALL_DIR}/.install-info" << EOF
VERSION=${VERSION}
SERVER_TYPE=${SERVER_TYPE}
EOF

# Set permissions
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$INSTALL_DIR"
chmod +x server.jar 2>/dev/null || true

# =============================================================================
# Systemd Service Update
# =============================================================================
log_step "Updating systemd service..."

# Detect container memory and set JVM heap accordingly (leave 1GB for OS)
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
HEAP_MB=$((TOTAL_MEM_MB - 1024))
if [[ $HEAP_MB -lt 1024 ]]; then HEAP_MB=1024; fi
HEAP_G=$(( (HEAP_MB + 1023) / 1024 ))

log_info "Detected ${TOTAL_MEM_MB}MB RAM. Setting JVM heap to ${HEAP_G}G."

cat > /etc/systemd/system/minecraft.service << EOF
[Unit]
Description=Minecraft ${SERVER_TYPE} Server
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/java -Xms${HEAP_G}G -Xmx${HEAP_G}G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=100 -XX:+DisableExplicitGC -XX:TargetSurvivorRatio=90 -XX:G1NewSizePercent=50 -XX:G1MaxNewSizePercent=80 -XX:G1MixedGCLiveThresholdPercent=50 -XX:+AlwaysPreTouch -jar server.jar nogui
Restart=on-failure
RestartSec=10
StandardOutput=append:${INSTALL_DIR}/logs/latest.log
StandardError=append:${INSTALL_DIR}/logs/latest.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable minecraft.service

# =============================================================================
# Firewall Configuration
# =============================================================================
log_step "Configuring firewall..."

if command -v ufw &>/dev/null; then
    ufw allow 25565/tcp comment "Minecraft Server" 2>/dev/null || true
    ufw allow 25575/tcp comment "Minecraft RCON" 2>/dev/null || true
    ufw reload 2>/dev/null || true
    log_info "UFW rules applied."
else
    log_warn "UFW not installed. Install with: apt-get install ufw"
fi

# =============================================================================
# First Run Preparation
# =============================================================================
log_step "Preparing for first run..."

log_info "Creating log directory..."
mkdir -p "${INSTALL_DIR}/logs"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}/logs"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================"
echo "  Minecraft Server Installed!"
echo "========================================"
echo "  Version:     ${VERSION}"
echo "  Type:        ${SERVER_TYPE}"
echo "  Directory:   ${INSTALL_DIR}"
echo "  User:        ${SERVICE_USER}"
echo "  Service:     minecraft.service"
echo "  JVM Heap:    ${HEAP_G}G (auto-detected from ${TOTAL_MEM_MB}MB RAM)"
echo ""
echo "  Quick Commands:"
echo "  Start:       systemctl start minecraft"
echo "  Stop:        systemctl stop minecraft"
echo "  Status:      systemctl status minecraft"
echo "  Logs:        journalctl -u minecraft -f"
echo "  Console:     tail -f ${INSTALL_DIR}/logs/latest.log"
echo ""
echo "  Edit config: nano ${INSTALL_DIR}/server.properties"
echo "  EULA Status: ${EULA_ACCEPT}"
echo ""
echo "  Next Step:"
echo "  Run: systemctl start minecraft"
echo "  Then: ${INSTALL_DIR}/scripts/test-minecraft.sh (if available)"
echo "========================================"
echo ""

log_info "Installation complete!"
