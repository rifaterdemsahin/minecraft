# Minecraft Server Troubleshooting Formula

## Quick Diagnosis Checklist

Run these commands **inside the LXC container** (via `pct exec 102 -- bash` or Proxmox console):

```bash
# 1. Check if Minecraft directory exists
ls -la /opt/minecraft/
# EXPECTED: server.jar, server.properties, eula.txt, logs/, world/
# IF MISSING: Run install-minecraft.sh

# 2. Check systemd service
systemctl status minecraft
# EXPECTED: active (running)
# IF "could not be found": Service not installed. Run install script.
# IF "inactive": Start with systemctl start minecraft

# 3. Check logs
journalctl -u minecraft --no-pager -n 50
# EXPECTED: "Done!" message with startup time
# IF "EULA not accepted": Set eula=true in /opt/minecraft/eula.txt
# IF Java errors: Check java -version (needs OpenJDK 21)

# 4. Check Java
java -version
# EXPECTED: openjdk version "21.x"
# IF MISSING: apt-get install openjdk-21-jre-headless

# 5. Check ports
ss -tlnp | grep 25565
# EXPECTED: LISTEN on :25565
# IF EMPTY: Server not running or crashed

# 6. Check EULA
cat /opt/minecraft/eula.txt
# EXPECTED: eula=true
# IF false: Server will refuse to start
```

## Common Errors & Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Unit minecraft.service could not be found` | Server never installed | Run `install-minecraft.sh` |
| `EULA not accepted` | eula.txt is false or missing | `echo "eula=true" > /opt/minecraft/eula.txt` |
| `Permission denied` on files | Wrong ownership | `chown -R minecraft:minecraft /opt/minecraft` |
| `OutOfMemoryError` | Too little RAM allocated | Increase `-Xmx` in systemd service or container memory |
| Port 25565 not listening | Server crashed or firewall | `systemctl start minecraft`, `ufw allow 25565` |
| `java: command not found` | Java not installed | `apt-get install openjdk-21-jre-headless` |
| Can't connect from LAN | Network/firewall issue | Check `ufw status`, verify `vmbr0` bridge |

## Fresh Install (When Nothing Exists)

If `/opt/minecraft/` doesn't exist, the server was never installed. Run this inside the container:

```bash
# Option A: Clone this repo and run install script
git clone https://github.com/rifaterdemsahin/minecraft.git /opt/minecraft/scripts
cd /opt/minecraft/scripts
./install-minecraft.sh 1.21.4 Paper
systemctl start minecraft
./test-minecraft.sh

# Option B: Manual quick install
mkdir -p /opt/minecraft
cd /opt/minecraft

# Download Paper 1.21.4
wget -O server.jar https://api.papermc.io/v2/projects/paper/versions/1.21.4/builds/222/downloads/paper-1.21.4-222.jar

# Accept EULA
echo "eula=true" > eula.txt

# Create systemd service
cat > /etc/systemd/system/minecraft.service << 'EOF'
[Unit]
Description=Minecraft Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/minecraft
ExecStart=/usr/bin/java -Xms2G -Xmx2G -jar server.jar nogui
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft
```

## Validate Installation

```bash
# Run the test script
./test-minecraft.sh 192.168.0.236 25565

# Or manual checks
systemctl is-active minecraft
ss -tlnp | grep 25565
journalctl -u minecraft | grep "Done ("
```

## Log Locations

| File | Purpose |
|------|---------|
| `/opt/minecraft/logs/latest.log` | Server game logs |
| `journalctl -u minecraft` | Systemd service logs |
| `/var/log/syslog` | System-level errors |

## Recovery: Complete Reset

```bash
# Stop server
systemctl stop minecraft

# Backup world (if exists)
tar -czf /root/world-backup-$(date +%s).tar.gz /opt/minecraft/world* 2>/dev/null || true

# Remove and reinstall
rm -rf /opt/minecraft/*
# Then run install-minecraft.sh again
```
