# Minecraft Server on Proxmox

Automated deployment of a Minecraft Java server on Proxmox VE using LXC containers.

## Quick Start

### 1. Create the LXC Container (on Proxmox host)

```bash
wget https://raw.githubusercontent.com/rifaterdemsahin/minecraft/main/scripts/proxmox-lxc-setup.sh
chmod +x proxmox-lxc-setup.sh
./proxmox-lxc-setup.sh 100 minecraft-server 8192 32
```

This creates an Ubuntu 24.04 LXC container with:
- Java 21 (OpenJDK)
- UFW firewall configured
- systemd service ready
- `minecraft` system user

### 2. Install Minecraft Server (inside LXC)

```bash
ssh root@<container-ip>
git clone git@github.com:rifaterdemsahin/minecraft.git /opt/minecraft/scripts
cd /opt/minecraft/scripts
./install-minecraft.sh 1.21.4 Paper
systemctl start minecraft
```

### 3. Validate (inside LXC)

```bash
./test-minecraft.sh
```

## Scripts

| Script | Where | Purpose |
|--------|-------|---------|
| `proxmox-lxc-setup.sh` | Proxmox host | Creates the LXC container |
| `install-minecraft.sh` | Inside LXC | Downloads & configures server JAR |
| `test-minecraft.sh` | Inside LXC | Validates server health |
| `manage-minecraft.sh` | Inside LXC | Daily operations (start/stop/backup) |

## Management Commands

```bash
# Start / Stop / Restart
./manage-minecraft.sh start
./manage-minecraft.sh stop
./manage-minecraft.sh restart

# View status and logs
./manage-minecraft.sh status
./manage-minecraft.sh logs

# Backup world (keeps last 7)
./manage-minecraft.sh backup

# Update to new version
./manage-minecraft.sh update
```

## Default Settings

| Setting | Value |
|---------|-------|
| Server Port | `25565` |
| RCON Port | `25575` |
| RAM | `6G` (`-Xms6G -Xmx6G`) |
| Java | OpenJDK 21 |
| Server Type | Paper (recommended) |
| World | `world/` |
| Backups | `/opt/minecraft/backups/` |

## EULA

The install script auto-accepts the Mojang EULA. If you do not agree, edit `/opt/minecraft/eula.txt` and set `eula=false` before starting.

## Connecting

Use your Proxmox host's IP address (or container IP if bridged directly) with port `25565`.

## License

Scripts are provided as-is for personal/self-hosted use.
