# Agent Guide: Minecraft Proxmox Project

This document provides context for AI agents working on this project.

## Project Overview

This repository contains automation scripts to deploy and manage a Minecraft Java server on a Proxmox VE host using LXC containers. The setup is designed for self-hosting with minimal manual intervention.

## Architecture

```
Proxmox VE Host
├── LXC Container (Ubuntu 24.04)
│   ├── systemd service: minecraft.service
│   ├── /opt/minecraft/
│   │   ├── server.jar          (Paper/Vanilla/Forge/Fabric)
│   │   ├── server.properties   (game config)
│   │   ├── eula.txt            (Mojang EULA)
│   │   ├── world/              (world data)
│   │   ├── logs/               (server logs)
│   │   ├── backups/            (world backups)
│   │   └── scripts/            (this repo)
│   └── Java 21 (OpenJDK)
└── Network: vmbr0 (DHCP)
    └── Ports: 25565 (Minecraft), 25575 (RCON), 22 (SSH)
```

## File Structure

```
.
├── AGENTS.md                        # This file
├── README.md                        # User-facing documentation
├── scripts/
│   ├── proxmox-lxc-setup.sh         # Run ONCE on Proxmox host to create LXC
│   ├── install-minecraft.sh         # Run INSIDE LXC to install/update server
│   ├── test-minecraft.sh           # Run INSIDE LXC to validate server health
│   └── manage-minecraft.sh         # Run INSIDE LXC for daily ops (start/stop/backup)
└── config/                          # (reserved for future config templates)
```

## Script Reference

### `scripts/proxmox-lxc-setup.sh`
- **Where**: Proxmox host (as root)
- **What**: Creates an Ubuntu 24.04 LXC container with Java 21, firewall rules, and a systemd service stub
- **Args**: `[CTID] [HOSTNAME] [MEMORY_MB] [DISK_GB]`
- **Output**: Container IP, root password saved to `proxmox-credentials-{CTID}.txt`
- **Idempotent**: No — fails if CTID already exists

### `scripts/install-minecraft.sh`
- **Where**: Inside LXC container (as root)
- **What**: Downloads and configures a Minecraft server JAR (Paper by default)
- **Args**: `[VERSION] [SERVER_TYPE]`
- **Supported Types**: `Paper`, `Vanilla`, `Forge`, `Fabric`
- **Idempotent**: Yes — backs up existing `server.jar`

### `scripts/test-minecraft.sh`
- **Where**: Inside LXC container (as root or any user)
- **What**: Validates service status, port listening, Minecraft ping, EULA, logs, disk/memory
- **Args**: `[HOST] [PORT] [TIMEOUT_SECONDS]`
- **Exit Code**: `0` = all passed, `1` = failures

### `scripts/manage-minecraft.sh`
- **Where**: Inside LXC container (as root)
- **What**: Daily operations wrapper (start, stop, restart, backup, update, console)
- **Args**: `[COMMAND]` (see script help)

## Common Workflows

### Fresh Deployment
```bash
# On Proxmox host
ssh root@proxmox-host
wget https://raw.githubusercontent.com/rifaterdemsahin/minecraft/main/scripts/proxmox-lxc-setup.sh
chmod +x proxmox-lxc-setup.sh
./proxmox-lxc-setup.sh 100 minecraft-server 8192 32

# Inside the new LXC container
ssh root@<container-ip>
git clone git@github.com:rifaterdemsahin/minecraft.git /opt/minecraft/scripts
cd /opt/minecraft/scripts
./install-minecraft.sh 1.21.4 Paper
systemctl start minecraft
./test-minecraft.sh
```

### Update Server Version
```bash
cd /opt/minecraft/scripts
./manage-minecraft.sh update
# or directly:
# ./install-minecraft.sh 1.21.5 Paper
```

### Backup World
```bash
./manage-minecraft.sh backup
# Backups stored in /opt/minecraft/backups/
# Auto-cleanup keeps last 7 backups
```

## Key Technical Details

| Setting | Value | Notes |
|---------|-------|-------|
| OS | Ubuntu 24.04 | LXC template |
| Java | OpenJDK 21 | Required for MC 1.20.5+ |
| Default RAM | 8GB | `-Xms6G -Xmx6G` in service |
| Default Disk | 32GB | Adjust as needed |
| Server Type | Paper (default) | Best performance/stability |
| Service User | `minecraft` | Runs server, owns files |
| Firewall | UFW | Ports 22, 25565, 25575 |
| Nesting | Enabled | Required for some Java features |

## Java Flags (Aikar's Flags)
The systemd service uses optimized GC flags for Minecraft servers. See `jvm-args.txt` in `/opt/minecraft/` for reference. Do not change unless you understand JVM tuning.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `EULA not accepted` | `eula.txt` is `false` | Set `eula=true` or pass `EULA_ACCEPT=true` to install script |
| Port 25565 not listening | Server crashed or not started | `systemctl start minecraft`, check `journalctl -u minecraft` |
| Out of memory | Too little RAM or world too large | Increase container RAM, reduce `view-distance` |
| Can't connect from LAN | Firewall or network issue | Check UFW (`ufw status`), verify `vmbr0` bridge |
| Lag / low TPS | Insufficient resources | Check `logs/latest.log` for tick warnings, reduce `simulation-distance` |

## Modification Guidelines for Agents

1. **Keep scripts POSIX-compliant where possible** — they run in minimal LXC containers.
2. **Never hardcode secrets** — generate passwords (like root password in LXC setup) and output them securely.
3. **Preserve idempotency in install-minecraft.sh** — always back up before overwriting.
4. **Use absolute paths** inside scripts (`/opt/minecraft/`), never relative paths for server operations.
5. **Update both README.md and AGENTS.md** when changing user-visible behavior.
6. **Test paths**: Scripts are designed to be tested in order: setup -> install -> test -> manage.

## Git Workflow

- Branch: `main`
- All scripts should be executable (`chmod +x`)
- Commit message format: `[area] description` (e.g., `scripts: add backup retention`)
- Push to `origin main` after changes
