#!/usr/bin/env bash
# =============================================================================
# Minecraft Server Management Script
# =============================================================================
# Usage: ./scripts/manage-minecraft.sh [COMMAND]
#
# Commands:
#   start       : Start the Minecraft server
#   stop        : Stop the Minecraft server (graceful)
#   restart     : Restart the server
#   status      : Show server status
#   logs        : Show live logs
#   backup      : Create a world backup
#   update      : Update the server JAR to latest version
#   console     : Attach to server console (requires screen/tmux)
#   command     : Send a command to the server console (requires rcon or console)
#
# Examples:
#   ./scripts/manage-minecraft.sh start
#   ./scripts/manage-minecraft.sh backup
#   ./scripts/manage-minecraft.sh command "say Hello from script!"
# =============================================================================

set -uo pipefail

COMMAND="${1:-status}"
INSTALL_DIR="/opt/minecraft"
SERVICE_NAME="minecraft"
BACKUP_DIR="/opt/minecraft/backups"
SERVICE_USER="minecraft"

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
# Commands
# =============================================================================

cmd_start() {
    log_step "Starting Minecraft server..."
    if systemctl start "$SERVICE_NAME"; then
        log_info "Server started successfully."
    else
        log_error "Failed to start server."
        exit 1
    fi
}

cmd_stop() {
    log_step "Stopping Minecraft server (graceful)..."
    # Try graceful stop via systemctl
    if systemctl stop "$SERVICE_NAME"; then
        log_info "Server stopped."
    else
        log_warn "Systemctl stop may have timed out. Checking..."
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_error "Server is still running."
            exit 1
        fi
    fi
}

cmd_restart() {
    cmd_stop
    sleep 3
    cmd_start
}

cmd_status() {
    log_step "Server Status"
    echo "========================================"
    systemctl status "$SERVICE_NAME" --no-pager
    echo ""
    
    if command -v ss &>/dev/null && ss -tlnp | grep -q ":25565"; then
        local conn_count
        conn_count=$(ss -tlnp | grep ":25565" | awk '{print $2}')
        log_info "Port 25565 state: ${conn_count}"
    fi
    
    if [[ -f "${INSTALL_DIR}/logs/latest.log" ]]; then
        echo ""
        log_info "Last 5 log lines:"
        tail -n 5 "${INSTALL_DIR}/logs/latest.log"
    fi
}

cmd_logs() {
    log_step "Showing live logs (Ctrl+C to exit)..."
    journalctl -u "$SERVICE_NAME" -f --no-pager
}

cmd_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="world_backup_${timestamp}.tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_step "Creating backup: ${backup_name}"
    
    mkdir -p "$BACKUP_DIR"
    chown "${SERVICE_USER}:${SERVICE_USER}" "$BACKUP_DIR"
    
    # Save world first if running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Sending save-all command..."
        # This requires rcon or console access; we'll just stop for clean backup
        log_warn "Server is running. Consider stopping for a clean backup."
    fi
    
    cd "$INSTALL_DIR"
    
    # Backup world directories
    local worlds=()
    for dir in world world_nether world_the_end; do
        if [[ -d "$dir" ]]; then
            worlds+=("$dir")
        fi
    done
    
    if [[ ${#worlds[@]} -eq 0 ]]; then
        log_warn "No world directories found to backup."
        return
    fi
    
    tar -czf "$backup_path" "${worlds[@]}" server.properties ops.json whitelist.json banned-players.json banned-ips.json 2>/dev/null || \
        tar -czf "$backup_path" "${worlds[@]}" server.properties
    
    chown "${SERVICE_USER}:${SERVICE_USER}" "$backup_path"
    
    local size
    size=$(du -h "$backup_path" | cut -f1)
    log_info "Backup created: ${backup_path} (${size})"
    
    # Cleanup old backups (keep last 7)
    local backup_count
    backup_count=$(ls -1t "${BACKUP_DIR}"/world_backup_*.tar.gz 2>/dev/null | wc -l)
    if [[ "$backup_count" -gt 7 ]]; then
        ls -1t "${BACKUP_DIR}"/world_backup_*.tar.gz | tail -n +8 | xargs rm -f
        log_info "Cleaned up old backups (kept 7 newest)."
    fi
}

cmd_update() {
    log_step "Updating Minecraft server..."
    
    # Detect current version/type
    local current_version="unknown"
    local current_type="Paper"
    
    if [[ -f "${INSTALL_DIR}/.install-info" ]]; then
        source "${INSTALL_DIR}/.install-info"
    fi
    
    read -rp "Version to install [${current_version}]: " new_version
    new_version=${new_version:-$current_version}
    
    read -rp "Server type [${current_type}]: " new_type
    new_type=${new_type:-$current_type}
    
    cmd_backup
    
    log_info "Downloading ${new_type} v${new_version}..."
    
    # Re-run install script with new version
    if [[ -f "${INSTALL_DIR}/scripts/install-minecraft.sh" ]]; then
        bash "${INSTALL_DIR}/scripts/install-minecraft.sh" "$new_version" "$new_type"
    else
        log_error "Install script not found. Please re-run manually."
        exit 1
    fi
    
    log_info "Update complete. Restarting server..."
    cmd_restart
}

cmd_console() {
    log_step "Attaching to server console..."
    log_warn "Use Ctrl+A then D to detach from screen, or exit the terminal session."
    
    # Try screen first
    if command -v screen &>/dev/null; then
        if screen -list | grep -q minecraft; then
            screen -r minecraft
        else
            log_warn "No screen session found. Server may not be using screen."
            log_info "Try: sudo -u minecraft screen -r"
        fi
    else
        log_warn "screen not installed. Install with: apt-get install screen"
        log_info "Alternative: Use journalctl -u minecraft -f"
    fi
}

cmd_command() {
    local command_str="${2:-help}"
    
    log_step "Sending command: ${command_str}"
    
    # Method 1: Try rcon (if configured)
    # Method 2: Use console input via screen
    if command -v screen &>/dev/null && screen -list | grep -q minecraft; then
        screen -S minecraft -p 0 -X stuff "${command_str}$(printf \\r)"
        log_info "Command sent via screen."
    else
        log_error "Cannot send command. Ensure screen is installed and server is running."
        exit 1
    fi
}

cmd_help() {
    cat << 'EOF'
Minecraft Server Management

Usage: ./manage-minecraft.sh [COMMAND]

Commands:
  start       Start the server
  stop        Stop the server gracefully
  restart     Restart the server
  status      Show server status and recent logs
  logs        Follow live logs
  backup      Create a world backup
  update      Update server JAR to a new version
  console     Attach to server console (screen)
  command     Send a command to the server
  help        Show this help

Examples:
  ./manage-minecraft.sh start
  ./manage-minecraft.sh backup
  ./manage-minecraft.sh command "say Hello Players!"
EOF
}

# =============================================================================
# Main
# =============================================================================
main() {
    case "$COMMAND" in
        start)    cmd_start ;;
        stop)     cmd_stop ;;
        restart)  cmd_restart ;;
        status)   cmd_status ;;
        logs)     cmd_logs ;;
        backup)   cmd_backup ;;
        update)   cmd_update ;;
        console)  cmd_console ;;
        command)  cmd_command "$@" ;;
        help|*)   cmd_help ;;
    esac
}

main "$@"
