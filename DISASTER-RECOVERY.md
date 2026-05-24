# Disaster Recovery Roadmap

Complete step-by-step disaster recovery for the Minecraft Proxmox server. Copy-pasteable commands for full rebuild from scratch.

> **Server:** CTID 102, Debian 12, Paper 1.21.11, Geyser + ViaVersion  
> **IP:** 192.168.0.236  
> **Java:** 25565 TCP, **Bedrock:** 19132 UDP

---

## Phase 0: Pre-Flight (Before You Start)

### Checklist
- [ ] Proxmox host is powered on and accessible
- [ ] You have root access to Proxmox host
- [ ] Container 102 does NOT exist (or you're OK wiping it)
- [ ] You know the Proxmox host IP or hostname

### Access Proxmox Host
```bash
ssh root@proxmox.rifaterdemsahin.com
# or
ssh root@192.168.0.1
```

---

## Phase 1: Create LXC Container (Proxmox Host)

```bash
# Set variables
CTID=102
HOSTNAME=minecraft-server
MEMORY=4096
DISK=8

# Download Debian 12 template if not present
pveam update
pveam download local debian-12-standard_12.0-1_amd64.tar.zst

# Create container
pct create $CTID local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
  --hostname $HOSTNAME \
  --memory $MEMORY \
  --swap 512 \
  --cores 2 \
  --rootfs local-lvm:${DISK} \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp,firewall=1 \
  --features nesting=1 \
  --onboot 1 \
  --start 1

# Verify
pct status $CTID
pct config $CTID | grep -E "memory|onboot|hostname"
```

---

## Phase 2: Install Base Tools (Inside Container)

```bash
# Enter container
pct exec 102 -- bash

# Install everything needed
apt-get update
apt-get install -y \
  curl wget jq git ufw screen htop net-tools \
  openjdk-21-jre-headless openjdk-21-jdk-headless

# Verify Java
java -version
```

---

## Phase 3: Create Minecraft User and Directories

```bash
# Create service user
useradd -m -s /bin/bash minecraft

# Create directories
mkdir -p /opt/minecraft/plugins /opt/minecraft/scripts /opt/minecraft/logs
chown -R minecraft:minecraft /opt/minecraft
```

---

## Phase 4: Download Paper Server

```bash
cd /opt/minecraft

# Get latest Paper version
PAPER_VERSION=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions | last')
echo "Latest Paper: $PAPER_VERSION"

# Get latest build
BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds" | \
  jq -r '.builds | last | .build')

# Download
wget -O server.jar \
  "https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds/${BUILD}/downloads/paper-${PAPER_VERSION}-${BUILD}.jar"

# Accept EULA
echo "eula=true" > eula.txt

# Basic config
cat > server.properties << 'EOF'
server-port=25565
motd=Mira and Arya's Server
max-players=20
online-mode=true
gamemode=survival
difficulty=easy
view-distance=10
simulation-distance=10
white-list=false
spawn-protection=16
EOF

chown -R minecraft:minecraft /opt/minecraft
```

---

## Phase 5: Create Systemd Service

```bash
cat > /etc/systemd/system/minecraft.service << 'EOF'
[Unit]
Description=Minecraft Paper Server
After=network.target

[Service]
Type=simple
User=minecraft
Group=minecraft
WorkingDirectory=/opt/minecraft
ExecStart=/usr/bin/java -Xms3G -Xmx3G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=100 -XX:+DisableExplicitGC -XX:TargetSurvivorRatio=90 -XX:G1NewSizePercent=50 -XX:G1MaxNewSizePercent=80 -XX:G1MixedGCLiveThresholdPercent=50 -XX:+AlwaysPreTouch -jar server.jar nogui
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft
```

---

## Phase 6: Verify Java Server

```bash
# Wait for startup
sleep 90

# Check status
systemctl is-active minecraft
ss -tlnp | grep 25565
journalctl -u minecraft --no-pager | grep "Done (" | tail -n 1
```

---

## Phase 7: Install GeyserMC (Bedrock Support)

```bash
cd /opt/minecraft

# Download Geyser
wget -O plugins/Geyser-Spigot.jar \
  https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot

# Download Floodgate
wget -O plugins/floodgate-spigot.jar \
  https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot

chown -R minecraft:minecraft plugins
```

---

## Phase 8: Install ViaVersion (Version Compatibility)

```bash
cd /opt/minecraft/plugins

# Download ViaVersion from GitHub releases (reliable)
wget -O ViaVersion.jar \
  https://github.com/ViaVersion/ViaVersion/releases/download/5.9.1/ViaVersion-5.9.1.jar

# Alternative: get latest release dynamically
# wget -O ViaVersion.jar $(curl -s https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest | grep browser_download_url | cut -d'"' -f4)

chown minecraft:minecraft ViaVersion.jar
```

---

## Phase 9: Firewall and Final Restart

```bash
# Open all required ports
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment SSH
ufw allow 25565/tcp comment Minecraft Java
ufw allow 25575/tcp comment Minecraft RCON
ufw allow 19132/udp comment Geyser Bedrock
ufw allow 19133/udp comment Geyser Query
ufw --force enable

# Verify rules
ufw status

# Restart server to load all plugins
systemctl restart minecraft

# Wait for full startup
sleep 90
```

---

## Phase 10: Full Verification

```bash
# Check all services
echo "=== Java Server ==="
systemctl is-active minecraft
ss -tlnp | grep 25565

echo "=== Geyser UDP ==="
ss -ulnp | grep 19132

echo "=== Plugins Loaded ==="
journalctl -u minecraft --no-pager | grep -E "ViaVersion|Geyser|floodgate" | tail -n 10

echo "=== Server Ready ==="
journalctl -u minecraft --no-pager | grep "Done (" | tail -n 1

echo "=== Test Boot ==="
cd /opt/minecraft/scripts
bash -c 'curl -fsSL -o test-boot.sh https://raw.githubusercontent.com/rifaterdemsahin/minecraft/main/scripts/test-boot.sh && chmod +x test-boot.sh && ./test-boot.sh'
```

---

## Phase 11: Clone Repo for Management Scripts

```bash
cd /opt/minecraft/scripts
git clone https://github.com/rifaterdemsahin/minecraft.git .
chmod +x *.sh
```

---

## Connection Details

| Platform | Client | Address | Port | Protocol |
|----------|--------|---------|------|----------|
| Java | PC/Mac/Linux | `192.168.0.236` | `25565` | TCP |
| Bedrock | iPad/iPhone/Xbox/Switch | `192.168.0.236` | `19132` | UDP |

---

## Quick Disaster Recovery (One-Liner)

If you have the container but lost everything inside:

```bash
pct exec 102 -- bash -c '
apt-get update && apt-get install -y curl wget jq git ufw screen openjdk-21-jre-headless
useradd -m -s /bin/bash minecraft 2>/dev/null || true
mkdir -p /opt/minecraft/plugins /opt/minecraft/scripts
cd /opt/minecraft
wget -O server.jar "https://api.papermc.io/v2/projects/paper/versions/$(curl -s https://api.papermc.io/v2/projects/paper | jq -r ".versions | last")/builds/$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$(curl -s https://api.papermc.io/v2/projects/paper | jq -r ".versions | last")/builds" | jq -r ".builds | last | .build")/downloads/paper-$(curl -s https://api.papermc.io/v2/projects/paper | jq -r ".versions | last")-$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$(curl -s https://api.papermc.io/v2/projects/paper | jq -r ".versions | last")/builds" | jq -r ".builds | last | .build").jar"
echo "eula=true" > eula.txt
wget -O plugins/Geyser-Spigot.jar https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot
wget -O plugins/floodgate-spigot.jar https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
wget -O plugins/ViaVersion.jar https://github.com/ViaVersion/ViaVersion/releases/download/5.9.1/ViaVersion-5.9.1.jar
chown -R minecraft:minecraft /opt/minecraft
systemctl restart minecraft
'
```

---

## Recovery Checklist

- [ ] Container 102 created and running
- [ ] Java 21 installed
- [ ] Paper server.jar downloaded
- [ ] EULA accepted
- [ ] systemd service enabled and started
- [ ] Port 25565 listening (Java)
- [ ] Geyser-Spigot.jar in plugins/
- [ ] Floodgate jar in plugins/
- [ ] ViaVersion jar in plugins/
- [ ] Port 19132 listening UDP (Bedrock)
- [ ] Firewall configured
- [ ] Server shows "Done!" in logs
- [ ] Can connect from Java client
- [ ] Can connect from iPad Bedrock

---

## What Each File Does (From Commit History)

| Commit | File | Purpose |
|--------|------|---------|
| `db4fad7` | `scripts/install-minecraft.sh` | Downloads and configures Paper server |
| `db4fad7` | `scripts/proxmox-lxc-setup.sh` | Creates LXC container on Proxmox host |
| `db4fad7` | `scripts/test-minecraft.sh` | Validates server health |
| `db4fad7` | `scripts/manage-minecraft.sh` | Daily ops (start/stop/backup) |
| `c7cec98` | `.env` | Stores credentials (gitignored) |
| `50fca1b` | `FORMULA.md` | Troubleshooting formula |
| `b7adc98` | `RESOLUTION.md` | Missing tools resolution |
| `52d502d` | `scripts/bootstrap-102.sh` | One-click bootstrap for CTID 102 |
| `9661561` | `RESOLUTION-PAPER-VERSION.md` | Paper version mismatch fix |
| `e3173dc` | `RESOLUTION-SERVER-STARTED.md` | Startup success log |
| `dab3375` | `scripts/test-boot.sh` | Auto-start verification |
| `5987a3c` | `.github/workflows/static.yml` | GitHub Pages deployment |
| `1b4a802` | `index.html` | Web dashboard |
| `1b4a802` | `markdown_renderer.html` | Markdown doc viewer with shared menu |
| `1b4a802` | `NEXT-START.md` | How to turn on next time |
| `139e775` | `KIDS-CONNECT.md` | Kid connection guide |
| `f7e50f5` | `scripts/setup-geyser.sh` | GeyserMC setup script |
| `f7e50f5` | `RESOLUTION-GEYSER.md` | Geyser troubleshooting |
| `b5fe440` | `RESOLUTION-VIAVERSION.md` | ViaVersion setup |
| `5cbdfbc` | `RESOLUTION-IPAD-FULL.md` | Complete iPad fix journey |

---

## GitHub Pages (Documentation)

| URL | Content |
|-----|---------|
| `https://rifaterdemsahin.github.io/minecraft/` | Dashboard with architecture |
| `https://rifaterdemsahin.github.io/minecraft/markdown_renderer.html` | Doc viewer with shared menu |

---

Last updated: 2026-05-24  
Status: ✅ **PRODUCTION READY**
