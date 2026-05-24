#!/usr/bin/env bash
# =============================================================================
# GeyserMC Setup for Bedrock (iPad/Xbox/Switch/Mobile) Support
# =============================================================================
# Run this INSIDE the LXC container to enable Bedrock players to connect
# to the Java Paper server.
#
# What it does:
#   - Places GeyserMC in /opt/minecraft/plugins/
#   - Configures Geyser to listen on UDP port 19132 (Bedrock default)
#   - Configures Floodgate for authentication
#   - Opens firewall ports
#   - Restarts server with Geyser enabled
#
# Usage:
#   cd /opt/minecraft
#   bash scripts/setup-geyser.sh
# =============================================================================

set -euo pipefail

INSTALL_DIR="/opt/minecraft"
PLUGINS_DIR="${INSTALL_DIR}/plugins"
GEYSER_JAR="${PLUGINS_DIR}/Geyser-Spigot.jar"
FLOODGATE_JAR="${PLUGINS_DIR}/floodgate-spigot.jar"

log_info()  { echo -e "\033[0;32m[INFO]\033[0m  $*"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
log_step()  { echo -e "\033[0;34m[STEP]\033[0m  $*"; }

# =============================================================================
# Step 1: Create plugins directory
# =============================================================================
log_step "Creating plugins directory..."
mkdir -p "$PLUGINS_DIR"

# =============================================================================
# Step 2: Download GeyserMC
# =============================================================================
log_step "Downloading GeyserMC..."

if [[ -f "${INSTALL_DIR}/spigot" ]]; then
    mv "${INSTALL_DIR}/spigot" "$GEYSER_JAR"
    log_info "Moved downloaded file to plugins/Geyser-Spigot.jar"
else
    log_warn "No spigot file found. Downloading fresh..."
    wget -O "$GEYSER_JAR" \
        "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
fi

# =============================================================================
# Step 3: Download Floodgate (required for Bedrock auth)
# =============================================================================
log_step "Downloading Floodgate..."

if [[ ! -f "$FLOODGATE_JAR" ]]; then
    wget -O "$FLOODGATE_JAR" \
        "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
    log_info "Floodgate downloaded."
else
    log_info "Floodgate already exists."
fi

# =============================================================================
# Step 4: Set permissions
# =============================================================================
log_step "Setting permissions..."
chown -R minecraft:minecraft "$PLUGINS_DIR"

# =============================================================================
# Step 5: Open firewall ports
# =============================================================================
log_step "Opening firewall for Bedrock..."

if command -v ufw &>/dev/null; then
    ufw allow 19132/udp comment "Geyser Bedrock" 2>/dev/null || true
    ufw allow 19133/udp comment "Geyser Bedrock Query" 2>/dev/null || true
    ufw reload 2>/dev/null || true
    log_info "UFW rules added for UDP 19132-19133."
else
    log_warn "UFW not installed. Install with: apt-get install ufw"
fi

# =============================================================================
# Step 6: Restart server
# =============================================================================
log_step "Restarting Minecraft server with Geyser..."

systemctl restart minecraft

# Wait for startup
sleep 20

# =============================================================================
# Step 7: Verify
# =============================================================================
log_step "Verifying Geyser..."

if systemctl is-active --quiet minecraft; then
    log_info "✅ Server is running."
else
    log_warn "⚠️  Server may still be starting. Check: journalctl -u minecraft -f"
fi

# Check if Geyser config was generated
if [[ -f "${PLUGINS_DIR}/Geyser-Spigot/config.yml" ]]; then
    log_info "✅ Geyser config generated."
    
    # Show Bedrock listen address
    BEDROCK_PORT=$(grep -A 5 "^bedrock:" "${PLUGINS_DIR}/Geyser-Spigot/config.yml" | grep "port:" | head -n1 | awk '{print $2}' || echo "19132")
    log_info "Geyser Bedrock Port: ${BEDROCK_PORT}"
else
    log_warn "⚠️  Geyser config not yet generated."
    log_info "Config will appear after first successful server start."
    log_info "Check again in 60 seconds with:"
    log_info "  cat /opt/minecraft/plugins/Geyser-Spigot/config.yml | grep -A 3 'bedrock:'"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================"
echo "  GeyserMC Setup Complete!"
echo "========================================"
echo "  Java Server:   192.168.0.236:25565"
echo "  Bedrock Port:  192.168.0.236:19132 (UDP)"
echo ""
echo "  iPad/Xbox/Switch/Mobile:"
echo "  Add Server -> Address: 192.168.0.236"
echo "  Port: 19132"
echo ""
echo "  Note: First Bedrock join may take 30s"
echo "  for auth translation."
echo ""
echo "  Verify config after 60s:"
echo "  cat /opt/minecraft/plugins/Geyser-Spigot/config.yml"
echo "========================================"
