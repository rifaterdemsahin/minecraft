# Minecraft Server on Proxmox

> **Live Docs:** https://rifaterdemsahin.github.io/minecraft/  
> **Markdown Renderer:** https://rifaterdemsahin.github.io/minecraft/markdown_renderer.html  
> **GitHub Repo:** https://github.com/rifaterdemsahin/minecraft

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
./install-minecraft.sh 1.21.11 Paper
systemctl start minecraft
```

> **Note:** Paper 1.21.4 is no longer available. Use `1.21.11` or omit the version to auto-detect latest.

### 3. Validate (inside LXC)

```bash
./test-boot.sh
```

## Scripts

| Script | Where | Purpose |
|--------|-------|---------|
| `proxmox-lxc-setup.sh` | Proxmox host | Creates the LXC container |
| `install-minecraft.sh` | Inside LXC | Downloads & configures server JAR |
| `test-minecraft.sh` | Inside LXC | Validates server health |
| `test-boot.sh` | Inside LXC | Verifies auto-start and boot persistence |
| `manage-minecraft.sh` | Inside LXC | Daily operations (start/stop/backup) |
| `bootstrap-102.sh` | Proxmox host | One-click bootstrap for container 102 |

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
| RAM | Auto-detected (container RAM - 1GB) |
| Java | OpenJDK 21 |
| Server Type | Paper (recommended) |
| World | `world/` |
| Backups | `/opt/minecraft/backups/` |

## Verified Server

| Property | Value |
|----------|-------|
| Container ID | `102` |
| IP Address | `192.168.0.236` |
| Version | Paper 1.21.11 build 69 |
| Java | Eclipse Temurin OpenJDK 21.0.9+10-LTS |
| OS | Debian 12 (bookworm) |
| RAM | 4096 MB (JVM heap: 3G) |

## EULA

The install script auto-accepts the Mojang EULA. If you do not agree, edit `/opt/minecraft/eula.txt` and set `eula=false` before starting.

## Connecting

Open Minecraft Java Edition → Multiplayer → Add Server:
- **Server Address:** `192.168.0.236:25565`

## Documentation

| Document | Purpose |
|----------|---------|
| [AGENTS.md](AGENTS.md) | Full architecture, troubleshooting, lessons learned |
| [FORMULA.md](FORMULA.md) | Diagnosis checklist, common errors, recovery steps |
| [NEXT-START.md](NEXT-START.md) | How to turn on the server next time |
| [RESOLUTION.md](RESOLUTION.md) | Missing tools fix, manual install fallback |
| [RESOLUTION-PAPER-VERSION.md](RESOLUTION-PAPER-VERSION.md) | Paper version mismatch fix |
| [RESOLUTION-SERVER-STARTED.md](RESOLUTION-SERVER-STARTED.md) | Startup success reference |

## License

Scripts are provided as-is for personal/self-hosted use.
