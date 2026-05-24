# Resolution: Missing Tools in LXC Container

## Problem

The LXC container (CTID 102) was created but lacks basic tools required to clone the repository and run the install scripts.

**Error observed:**
```bash
bash: git: command not found
bash: cd: /opt/minecraft/scripts: No such file or directory
bash: ./install-minecraft.sh: No such file or directory
```

## Root Cause

The container was created with a minimal Debian 12 image. Unlike the `proxmox-lxc-setup.sh` script (which installs curl, wget, jq, git, ufw, Java, etc.), this container was created manually or via a different method and is missing:

| Missing Tool | Needed For |
|--------------|-----------|
| `git` | Cloning the repository |
| `curl` | Downloading server JARs |
| `wget` | Alternative download method |
| `jq` | Parsing JSON APIs (Paper builds, Mojang manifest) |
| `ufw` | Firewall management |
| `screen` | Server console attachment |

## Resolution Steps

### Step 1: Install Required Tools (inside container)

```bash
# Already inside container via: pct exec 102 -- bash

apt-get update
apt-get install -y curl wget jq git ufw screen htop net-tools
```

### Step 2: Install Minecraft Server

**Option A: Use the updated install script (no git required)**

The `install-minecraft.sh` script has been updated to auto-install missing dependencies (curl, wget, jq) and does not require git.

Download and run it directly:

```bash
# Inside container
mkdir -p /opt/minecraft/scripts
cd /opt/minecraft/scripts

# Download the script directly from GitHub raw
curl -fsSL -o install-minecraft.sh \
  https://raw.githubusercontent.com/rifaterdemsahin/minecraft/main/scripts/install-minecraft.sh
chmod +x install-minecraft.sh
./install-minecraft.sh 1.21.4 Paper
```

**Option B: Manual install (if curl also fails)**

```bash
# Inside container
apt-get install -y curl wget jq openjdk-21-jre-headless

mkdir -p /opt/minecraft
cd /opt/minecraft

# Download Paper 1.21.4
wget -O server.jar \
  https://api.papermc.io/v2/projects/paper/versions/1.21.4/builds/222/downloads/paper-1.21.4-222.jar

# Accept EULA
echo "eula=true" > eula.txt

# Create minimal server.properties
cat > server.properties << 'EOF'
server-port=25565
motd=A Minecraft Server
max-players=20
online-mode=true
EOF

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

### Step 3: Verify Installation

```bash
# Check service status
systemctl status minecraft

# Check logs
journalctl -u minecraft --no-pager -n 50

# Check port
ss -tlnp | grep 25565

# Test from another machine
python3 -c "
import socket, struct, json
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(5)
sock.connect(('192.168.0.236', 25565))
data = b'\x00\x00' + struct.pack('>H', len('192.168.0.236')) + b'192.168.0.236' + struct.pack('>H', 25565) + b'\x01'
sock.sendall(struct.pack('>B', len(data)) + data)
sock.sendall(b'\x01\x00')
length = struct.unpack('>B', sock.recv(1))[0]
packet_id = struct.unpack('>B', sock.recv(1))[0]
json_length = struct.unpack('>H', sock.recv(2))[0]
response = json.loads(sock.recv(json_length).decode('utf-8'))
print(f\"Version: {response['version']['name']}\")
print(f\"Players: {response['players']['online']}/{response['players']['max']}\")
sock.close()
"
```

## Prevention

### Update `proxmox-lxc-setup.sh` to auto-install tools

The setup script should ensure all required packages are installed inside the container during creation. This has been addressed in the current version of `proxmox-lxc-setup.sh` which runs:

```bash
apt-get install -y curl wget jq git nano htop net-tools ufw \
    openjdk-21-jre-headless openjdk-21-jdk-headless \
    screen cron
```

### Alternative: Use the Proxmox host to push files

If the container lacks network access or package manager, use the Proxmox host to push files directly:

```bash
# On Proxmox host
pct push 102 /path/to/install-minecraft.sh /root/install-minecraft.sh
pct exec 102 -- bash /root/install-minecraft.sh
```

## References

- [FORMULA.md](FORMULA.md) — General troubleshooting guide
- [AGENTS.md](AGENTS.md) — Architecture and workflow documentation
- [scripts/install-minecraft.sh](scripts/install-minecraft.sh) — Updated install script with dependency checks
