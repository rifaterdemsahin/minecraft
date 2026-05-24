#!/usr/bin/env bash
# =============================================================================
# Minecraft Server Validation & Test Script
# =============================================================================
# Usage: ./scripts/test-minecraft.sh [HOST] [PORT] [TIMEOUT_SECONDS]
#
# Arguments:
#   HOST     : Server hostname or IP (default: localhost)
#   PORT     : Minecraft server port (default: 25565)
#   TIMEOUT  : Max wait time for server to become ready (default: 300)
#
# This script performs the following tests:
#   1. Service status check (systemd)
#   2. Port listening verification
#   3. Server query (Minecraft Server List Ping protocol)
#   4. EULA acceptance check
#   5. Log file health check
#   6. Basic connectivity from external perspective
#
# Exit codes:
#   0 : All tests passed
#   1 : One or more tests failed
# =============================================================================

set -uo pipefail

# --- Configuration ---
HOST="${1:-localhost}"
PORT="${2:-25565}"
TIMEOUT="${3:-300}"
INSTALL_DIR="/opt/minecraft"
SERVICE_NAME="minecraft"

# Colors
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
# Test 1: Systemd Service Status
# =============================================================================
test_service_status() {
    log_step "Checking systemd service status..."
    
    if ! command -v systemctl &>/dev/null; then
        log_warn "systemctl not found. Skipping service check."
        return
    fi
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        local uptime
        uptime=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value 2>/dev/null | awk '{print $2, $3, $4}')
        log_pass "Service '${SERVICE_NAME}' is ACTIVE (since ${uptime})"
    else
        log_fail "Service '${SERVICE_NAME}' is NOT active."
        log_info "Run: systemctl start ${SERVICE_NAME}"
        log_info "Check logs: journalctl -u ${SERVICE_NAME} --no-pager -n 50"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        log_pass "Service '${SERVICE_NAME}' is ENABLED on boot"
    else
        log_warn "Service '${SERVICE_NAME}' is NOT enabled on boot."
        log_info "Run: systemctl enable ${SERVICE_NAME}"
    fi
}

# =============================================================================
# Test 2: Port Listening Check
# =============================================================================
test_port_listening() {
    log_step "Checking if port ${PORT} is listening..."
    
    if command -v ss &>/dev/null; then
        if ss -tlnp | grep -q ":${PORT}"; then
            local proc
            proc=$(ss -tlnp | grep ":${PORT}" | awk '{print $7}')
            log_pass "Port ${PORT} is LISTENING (${proc})"
        else
            log_fail "Port ${PORT} is NOT listening."
        fi
    elif command -v netstat &>/dev/null; then
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
# Test 3: Minecraft Server List Ping (SLP)
# =============================================================================
test_minecraft_ping() {
    log_step "Performing Minecraft Server List Ping..."
    
    # Check if we have Python for a proper ping test
    if command -v python3 &>/dev/null; then
        local ping_result
        ping_result=$(python3 -c '
import socket, struct, json, sys

def ping_server(host, port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((host, port))
        
        # Handshake packet
        data = b"\x00\x00"
        data += struct.pack(">H", len(host.encode("utf-8")))
        data += host.encode("utf-8")
        data += struct.pack(">H", port)
        data += b"\x01"
        
        packet = struct.pack(">B", len(data)) + data
        sock.sendall(packet)
        
        # Status request
        sock.sendall(b"\x01\x00")
        
        # Read response
        length = struct.unpack(">B", sock.recv(1))[0]
        packet_id = struct.unpack(">B", sock.recv(1))[0]
        json_length = struct.unpack(">H", sock.recv(2))[0]
        response = sock.recv(json_length).decode("utf-8")
        sock.close()
        
        data = json.loads(response)
        version = data.get("version", {}).get("name", "unknown")
        players = data.get("players", {})
        motd = data.get("description", {}).get("text", "No MOTD")
        print(f"VERSION={version}|ONLINE={players.get(\"online\", 0)}|MAX={players.get(\"max\", 0)}|MOTD={motd}")
        return 0
    except Exception as e:
        print(f"ERROR={e}")
        return 1

sys.exit(ping_server("'"$HOST"'", '"$PORT"'))
' 2>/dev/null)

        if [[ "$ping_result" == ERROR=* ]]; then
            log_fail "Minecraft ping failed: ${ping_result#ERROR=}"
        elif [[ -n "$ping_result" ]]; then
            IFS='|' read -r -a parts <<< "$ping_result"
            for part in "${parts[@]}"; do
                log_pass "Ping response: $part"
            done
        else
            log_fail "Minecraft ping returned empty response."
        fi
    else
        log_warn "Python3 not available. Using basic TCP check instead."
        if timeout 5 bash -c "exec 3<>/dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
            log_pass "TCP connection to ${HOST}:${PORT} succeeded"
        else
            log_fail "TCP connection to ${HOST}:${PORT} failed"
        fi
    fi
}

# =============================================================================
# Test 4: EULA Check
# =============================================================================
test_eula() {
    log_step "Checking EULA acceptance..."
    
    if [[ -f "${INSTALL_DIR}/eula.txt" ]]; then
        if grep -q "^eula=true" "${INSTALL_DIR}/eula.txt"; then
            log_pass "EULA is accepted."
        else
            log_fail "EULA is NOT accepted. Set eula=true in ${INSTALL_DIR}/eula.txt"
        fi
    else
        log_fail "eula.txt not found at ${INSTALL_DIR}/eula.txt"
    fi
}

# =============================================================================
# Test 5: Log Health Check
# =============================================================================
test_logs() {
    log_step "Checking server logs for errors..."
    
    local latest_log="${INSTALL_DIR}/logs/latest.log"
    
    if [[ ! -f "$latest_log" ]]; then
        log_warn "No log file found at ${latest_log}. Server may not have started yet."
        return
    fi
    
    # Check for critical errors in recent logs
    local critical_count
    critical_count=$(grep -c -i "FATAL\|CRITICAL\| severe \|exception\|error" "$latest_log" 2>/dev/null || echo "0")
    
    if [[ "$critical_count" -eq 0 ]]; then
        log_pass "No critical errors found in logs."
    else
        log_warn "Found ${critical_count} potential error(s) in logs."
        log_info "Check: tail -n 50 ${latest_log}"
    fi
    
    # Check if server finished starting
    if grep -q "Done (" "$latest_log" 2>/dev/null; then
        local startup_time
        startup_time=$(grep "Done (" "$latest_log" | tail -n1 | grep -oP 'Done \(\K[^!]+')
        log_pass "Server startup completed in ${startup_time}"
    else
        log_warn "Server may still be starting or failed to start."
    fi
}

# =============================================================================
# Test 6: Wait for Server Ready
# =============================================================================
test_wait_for_ready() {
    log_step "Waiting up to ${TIMEOUT}s for server to become ready..."
    
    local start_time
    start_time=$(date +%s)
    local elapsed=0
    
    while [[ $elapsed -lt $TIMEOUT ]]; do
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            if [[ -f "${INSTALL_DIR}/logs/latest.log" ]] && grep -q "Done (" "${INSTALL_DIR}/logs/latest.log" 2>/dev/null; then
                log_pass "Server is ready! (waited ${elapsed}s)"
                return
            fi
        else
            log_warn "Service is not active during wait."
            return
        fi
        
        sleep 5
        elapsed=$(($(date +%s) - start_time))
        echo -ne "\r  Waiting... ${elapsed}s / ${TIMEOUT}s"
    done
    echo
    log_fail "Server did not become ready within ${TIMEOUT}s."
}

# =============================================================================
# Test 7: Disk Space Check
# =============================================================================
test_disk_space() {
    log_step "Checking disk space..."
    
    local usage
    usage=$(df "$INSTALL_DIR" | tail -n1 | awk '{print $5}' | tr -d '%')
    
    if [[ "$usage" -lt 80 ]]; then
        log_pass "Disk usage: ${usage}% (healthy)"
    elif [[ "$usage" -lt 95 ]]; then
        log_warn "Disk usage: ${usage}% (getting full)"
    else
        log_fail "Disk usage: ${usage}% (critical!)"
    fi
}

# =============================================================================
# Test 8: Memory Check
# =============================================================================
test_memory() {
    log_step "Checking memory availability..."
    
    if command -v free &>/dev/null; then
        local mem_info
        mem_info=$(free -m | awk '/^Mem:/{print $7}')
        log_pass "Available memory: ${mem_info}MB"
    else
        log_warn "'free' command not available. Skipping memory check."
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "========================================"
    echo "  Minecraft Server Validation Suite"
    echo "========================================"
    echo "  Target: ${HOST}:${PORT}"
    echo "  Timeout: ${TIMEOUT}s"
    echo "========================================"
    echo ""
    
    test_service_status
    test_port_listening
    test_eula
    test_disk_space
    test_memory
    test_logs
    test_wait_for_ready
    test_minecraft_ping
    
    # Summary
    echo ""
    echo "========================================"
    echo "  Test Results"
    echo "========================================"
    echo -e "  ${GREEN}Passed: ${PASS}${NC}"
    echo -e "  ${RED}Failed: ${FAIL}${NC}"
    echo "========================================"
    echo ""
    
    if [[ $FAIL -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! Minecraft server is healthy.${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed. Review the output above.${NC}"
        exit 1
    fi
}

main "$@"
