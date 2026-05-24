#!/usr/bin/env bash
# =============================================================================
# Minecraft Server Boot Test & Auto-Start Verification
# =============================================================================
# Run this INSIDE the LXC container to verify the server starts automatically
# on boot and is currently healthy.
#
# Usage:
#   ./scripts/test-boot.sh
#
# This script checks:
#   1. systemd service is enabled (starts on boot)
#   2. systemd service is currently active
#   3. Port 25565 is listening
#   4. Minecraft Server List Ping responds
#   5. World files exist
# =============================================================================

set -uo pipefail

HOST="${1:-192.168.0.236}"
PORT="${2:-25565}"
INSTALL_DIR="/opt/minecraft"
SERVICE_NAME="minecraft"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

log_pass()  { echo -e "${GREEN}[PASS]${NC}  $*"; ((PASS++)); }
log_fail()  { echo -e "${RED}[FAIL]${NC}  $*"; ((FAIL++)); }
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_step()  { echo -e "${BLUE}[TEST]${NC}  $*"; }

# =============================================================================
# Test 1: Service Enabled (Auto-Start on Boot)
# =============================================================================
test_service_enabled() {
    log_step "Checking if service is enabled for auto-start..."
    
    if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        log_pass "Service '${SERVICE_NAME}' is ENABLED — will start on boot"
    else
        log_fail "Service '${SERVICE_NAME}' is NOT enabled."
        log_info "Fix: systemctl enable ${SERVICE_NAME}"
    fi
}

# =============================================================================
# Test 2: Service Currently Active
# =============================================================================
test_service_active() {
    log_step "Checking if service is currently running..."
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        local uptime
        uptime=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value 2>/dev/null | awk '{print $2, $3, $4}')
        log_pass "Service '${SERVICE_NAME}' is ACTIVE (since ${uptime})"
    else
        log_fail "Service '${SERVICE_NAME}' is NOT active."
        log_info "Fix: systemctl start ${SERVICE_NAME}"
    fi
}

# =============================================================================
# Test 3: Port Listening
# =============================================================================
test_port_listening() {
    log_step "Checking if port ${PORT} is listening..."
    
    if command -v ss >/dev/null 2>&1; then
        if ss -tlnp | grep -q ":${PORT}"; then
            local proc
            proc=$(ss -tlnp | grep ":${PORT}" | awk '{print $7}')
            log_pass "Port ${PORT} is LISTENING (${proc})"
        else
            log_fail "Port ${PORT} is NOT listening."
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tlnp 2>/dev/null | grep -q ":${PORT}"; then
            log_pass "Port ${PORT} is LISTENING"
        else
            log_fail "Port ${PORT} is NOT listening."
        fi
    else
        log_warn "Neither 'ss' nor 'netstat' available. Skipping port check."
    fi
}

# =============================================================================
# Test 4: Minecraft Server List Ping
# =============================================================================
test_minecraft_ping() {
    log_step "Performing Minecraft Server List Ping..."
    
    if command -v python3 >/dev/null 2>&1; then
        local ping_result
        ping_result=$(python3 << 'PYEOF'
import socket, struct, json, sys

def ping_server(host, port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((host, port))
        
        data = b"\x00\x00"
        data += struct.pack(">H", len(host.encode("utf-8")))
        data += host.encode("utf-8")
        data += struct.pack(">H", port)
        data += b"\x01"
        
        packet = struct.pack(">B", len(data)) + data
        sock.sendall(packet)
        
        sock.sendall(b"\x01\x00")
        
        length = struct.unpack(">B", sock.recv(1))[0]
        packet_id = struct.unpack(">B", sock.recv(1))[0]
        json_length = struct.unpack(">H", sock.recv(2))[0]
        response = sock.recv(json_length).decode("utf-8")
        sock.close()
        
        data = json.loads(response)
        version = data.get("version", {}).get("name", "unknown")
        players = data.get("players", {})
        motd = data.get("description", {}).get("text", "No MOTD")
        print(f"VERSION={version}")
        print(f"ONLINE={players.get('online', 0)}")
        print(f"MAX={players.get('max', 0)}")
        print(f"MOTD={motd}")
        return 0
    except Exception as e:
        print(f"ERROR: {e}")
        return 1

sys.exit(ping_server("192.168.0.236", 25565))
PYEOF
)

        if [[ "$ping_result" == ERROR=* ]]; then
            log_fail "Minecraft ping failed: ${ping_result#ERROR=}"
        else
            echo "$ping_result" | while read -r line; do
                log_pass "Ping response: $line"
            done
        fi
    else
        log_warn "Python3 not available. Using basic TCP check."
        if timeout 5 bash -c "exec 3<>/dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
            log_pass "TCP connection to ${HOST}:${PORT} succeeded"
        else
            log_fail "TCP connection to ${HOST}:${PORT} failed"
        fi
    fi
}

# =============================================================================
# Test 5: World Files Exist
# =============================================================================
test_world_files() {
    log_step "Checking world files..."
    
    local world_exists=false
    if [[ -d "${INSTALL_DIR}/world" ]]; then
        log_pass "World directory exists"
        world_exists=true
    else
        log_warn "World directory not found (server may still be starting)"
    fi
    
    if [[ -f "${INSTALL_DIR}/server.properties" ]]; then
        log_pass "server.properties exists"
    else
        log_fail "server.properties missing"
    fi
    
    if [[ -f "${INSTALL_DIR}/eula.txt" ]]; then
        if grep -q "^eula=true" "${INSTALL_DIR}/eula.txt"; then
            log_pass "EULA is accepted"
        else
            log_fail "EULA is NOT accepted"
        fi
    else
        log_fail "eula.txt missing"
    fi
}

# =============================================================================
# Test 6: Boot Persistence Check
# =============================================================================
test_boot_persistence() {
    log_step "Checking boot persistence configuration..."
    
    # Check systemd wants symlink
    if [[ -L "/etc/systemd/system/multi-user.target.wants/minecraft.service" ]]; then
        log_pass "Boot symlink exists in multi-user.target.wants"
    else
        log_warn "Boot symlink not found. Service may not auto-start."
        log_info "Fix: systemctl enable minecraft"
    fi
    
    # Check container onboot setting (Proxmox)
    if [[ -f /proc/1/environ ]] && strings /proc/1/environ | grep -q "container"; then
        log_info "Running inside container. Ensure Proxmox 'onboot' is enabled."
        log_info "On Proxmox host: pct config 102 | grep onboot"
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "========================================"
    echo "  Minecraft Server Boot Test Suite"
    echo "========================================"
    echo "  Target: ${HOST}:${PORT}"
    echo "  Time: $(date)"
    echo "========================================"
    echo ""
    
    test_service_enabled
    test_service_active
    test_port_listening
    test_minecraft_ping
    test_world_files
    test_boot_persistence
    
    echo ""
    echo "========================================"
    echo "  Test Results"
    echo "========================================"
    echo -e "  ${GREEN}Passed: ${PASS}${NC}"
    echo -e "  ${RED}Failed: ${FAIL}${NC}"
    echo "========================================"
    echo ""
    
    if [[ $FAIL -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! Server is healthy and will auto-start on boot.${NC}"
        echo ""
        echo "  Connect with Minecraft Java:"
        echo "  Server Address: ${HOST}:${PORT}"
        echo ""
        exit 0
    else
        echo -e "${RED}Some tests failed. Review the output above.${NC}"
        echo ""
        echo "  Quick fixes:"
        echo "  Enable auto-start:  systemctl enable minecraft"
        echo "  Start now:          systemctl start minecraft"
        echo "  Check logs:         journalctl -u minecraft -f"
        echo ""
        exit 1
    fi
}

main "$@"
