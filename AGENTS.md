# Agent Guide: Minecraft Proxmox Project

This document provides context for AI agents working on this project.

## Project Overview

This repository contains automation scripts to deploy and manage a Minecraft Java server on a Proxmox VE host using LXC containers. The setup is designed for self-hosting with minimal manual intervention.

## Verified Architecture (As-Built)

```
Proxmox VE Host (proxmox.rifaterdemsahin.com)
├── LXC Container 102 (Debian 12 — NOT Ubuntu 24.04)
│   ├── systemd service: minecraft.service (ENABLED, auto-starts on boot)
│   ├── /opt/minecraft/
│   │   ├── server.jar          (Paper 1.21.11 build 69, 52MB)
│   │   ├── server.properties   (game config)
│   │   ├── eula.txt            (eula=true, auto-accepted)
│   │   ├── world/              (world data — generated)
│   │   ├── world_nether/       (nether — generated)
│   │   ├── world_the_end/      (end — generated)
│   │   ├── logs/               (server logs)
│   │   ├── backups/            (world backups)
│   │   └── scripts/            (this repo, cloned)
│   ├── Java 21 (Eclipse Temurin OpenJDK 21.0.9+10-LTS)
│   └── Installed packages: curl, wget, jq, git, ufw, screen, htop, net-tools
└── Network: vmbr0 (DHCP)
    └── Ports: 25565 (Minecraft), 25575 (RCON), 22 (SSH)
```

## Container Details (CTID 102)

| Setting | Actual Value | Notes |
|---------|-------------|-------|
| CTID | 102 | Fixed, not 100 |
| OS | Debian 12 (bookworm) | NOT Ubuntu 24.04 |
| Hostname | minecraft-server | |
| IP | 192.168.0.236 | DHCP on vmbr0 |
| MAC | BC:24:11:BC:32:41 | |
| RAM | 4096 MB (4GB) | `-Xms3G -Xmx3G` auto-detected |
| Disk | 8GB | rootfs on local-lvm |
| Cores | 2 | |
| Swap | 512MB | |
| Unprivileged | 1 | |
| Nesting | Enabled | Required for Java features |
| onboot | MUST be 1 | Check: `pct config 102 \| grep onboot` |

## File Structure

```
.
├── AGENTS.md                        # This file — architecture & context
├── README.md                        # User-facing quick-start
├── FORMULA.md                       # Troubleshooting formula
├── RESOLUTION.md                    # Missing tools resolution
├── RESOLUTION-PAPER-VERSION.md      # Paper version mismatch fix
├── RESOLUTION-SERVER-STARTED.md     # Startup success log
├── NEXT-START.md                    # How to turn on next time
├── index.html                       # Web dashboard (architecture + steps)
├── .env                             # Local credentials (gitignored)
├── .gitignore                       # Excludes .env, credentials, runtime files
├── scripts/
│   ├── proxmox-lxc-setup.sh         # Run ONCE on Proxmox host to create LXC
│   ├── install-minecraft.sh         # Run INSIDE LXC to install/update server
│   ├── test-minecraft.sh           # Run INSIDE LXC to validate server health
│   ├── test-boot.sh                # Run INSIDE LXC to verify auto-start
│   ├── manage-minecraft.sh           # Run INSIDE LXC for daily ops
│   └── bootstrap-102.sh            # Run ONCE on Proxmox host for CTID 102
└── config/                          # (reserved for future config templates)
```

## Script Reference

### `scripts/proxmox-lxc-setup.sh`
- **Where**: Proxmox host (as root)
- **What**: Creates an Ubuntu 24.04 LXC container with Java 21, firewall rules, and a systemd service stub
- **Args**: `[CTID] [HOSTNAME] [MEMORY_MB] [DISK_GB]`
- **Output**: Container IP, root password saved to `proxmox-credentials-{CTID}.txt`
- **Idempotent**: No — fails if CTID already exists
- **Loads `.env`**: Yes, reads `DEFAULT_CTID`, `DEFAULT_HOSTNAME`, `DEFAULT_MEMORY_MB`, `DEFAULT_DISK_GB`

### `scripts/install-minecraft.sh`
- **Where**: Inside LXC container (as root)
- **What**: Downloads and configures a Minecraft server JAR (Paper by default)
- **Args**: `[VERSION] [SERVER_TYPE]`
- **Supported Types**: `Paper`, `Vanilla`, `Forge`, `Fabric`
- **Idempotent**: Yes — backs up existing `server.jar`
- **Auto-detects latest Paper version**: If no version specified, fetches from PaperMC API
- **Fallback builds**: If `default` channel has no builds, falls back to `experimental`/`rc`
- **Auto-detects RAM**: Sets JVM heap to `total RAM - 1GB` (minimum 1GB)
- **Auto-installs missing tools**: curl, wget, jq if not present

### `scripts/test-minecraft.sh`
- **Where**: Inside LXC container (as root or any user)
- **What**: Validates service status, port listening, Minecraft ping, EULA, logs, disk/memory
- **Args**: `[HOST] [PORT] [TIMEOUT_SECONDS]`
- **Exit Code**: `0` = all passed, `1` = failures

### `scripts/test-boot.sh`
- **Where**: Inside LXC container (as root)
- **What**: Verifies auto-start is enabled, service is active, port is listening, ping responds
- **Checks**: `systemctl is-enabled`, `systemctl is-active`, `ss -tlnp`, Minecraft SLP, world files, boot symlink
- **Exit Code**: `0` = all passed, `1` = failures

### `scripts/manage-minecraft.sh`
- **Where**: Inside LXC container (as root)
- **What**: Daily operations wrapper (start, stop, restart, backup, update, console)
- **Args**: `[COMMAND]` (see script help)

### `scripts/bootstrap-102.sh`
- **Where**: Proxmox host (as root)
- **What**: One-click bootstrap for container 102 — installs tools, pushes installer, starts server
- **Use case**: When container exists but Minecraft was never installed

## Common Workflows

### Fresh Deployment (New Container)
```bash
# On Proxmox host
ssh root@proxmox.rifaterdemsahin.com
wget https://raw.githubusercontent.com/rifaterdemsahin/minecraft/main/scripts/proxmox-lxc-setup.sh
chmod +x proxmox-lxc-setup.sh
./proxmox-lxc-setup.sh 100 minecraft-server 8192 32

# Inside the new LXC container
ssh root@<container-ip>
git clone https://github.com/rifaterdemsahin/minecraft.git /opt/minecraft/scripts
cd /opt/minecraft/scripts
./install-minecraft.sh 1.21.11 Paper   # Use latest version, NOT 1.21.4
systemctl start minecraft
./test-boot.sh
```

### Existing Container (CTID 102) — Tools Missing
```bash
# Inside container 102
apt-get update && apt-get install -y curl wget jq git ufw screen
mkdir -p /opt/minecraft/scripts && cd /opt/minecraft/scripts
curl -fsSL -o install-minecraft.sh \
  https://raw.githubusercontent.com/rifaterdemsahin/minecraft/main/scripts/install-minecraft.sh
chmod +x install-minecraft.sh
./install-minecraft.sh 1.21.11 Paper
systemctl start minecraft
./test-boot.sh
```

### Turn On Next Time (After Reboot)
See [NEXT-START.md](NEXT-START.md) for full procedure.

Quick version:
```bash
# On Proxmox host
pct start 102

# Inside container (after 30s)
./test-boot.sh
# If not running: systemctl start minecraft
```

### Update Server Version
```bash
cd /opt/minecraft/scripts
./manage-minecraft.sh update
# or directly:
# ./install-minecraft.sh <LATEST_VERSION> Paper
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
| OS | Debian 12 (bookworm) | Actual installed OS, not Ubuntu |
| Java | Eclipse Temurin OpenJDK 21.0.9+10-LTS | Required for MC 1.20.5+ |
| Container RAM | 4096 MB (4GB) | `-Xms3G -Xmx3G` auto-detected |
| Container Disk | 8GB | rootfs on local-lvm |
| Server Type | Paper (default) | Best performance/stability |
| Paper Version | 1.21.11 build 69 | Latest as of 2026-05-24 |
| Service User | `minecraft` | Runs server, owns files |
| Firewall | UFW | Ports 22, 25565, 25575 |
| Nesting | Enabled | Required for some Java features |
| Auto-start | `systemctl enable minecraft` | Creates symlink in multi-user.target.wants |
| Boot persistence | `pct set 102 --onboot 1` | On Proxmox host |

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
| `git: command not found` | Minimal Debian image | `apt-get install git curl wget jq` |
| `Could not find Paper build` | Version no longer supported | Use latest version from API, or omit version arg |
| `Unit minecraft.service could not be found` | Server never installed | Run `install-minecraft.sh` |
| `Permission denied (publickey,password)` | SSH key only, no password | Use Proxmox console or `pct exec` |
| Server not auto-starting on boot | Service not enabled | `systemctl enable minecraft` |
| Container not auto-starting | Proxmox `onboot` not set | On host: `pct set 102 --onboot 1` |

## Lessons Learned (2026-05-24)

1. **Paper version 1.21.4 is no longer available** — API returns no builds. Always use latest or omit version.
2. **Debian 12 minimal images lack basic tools** — `git`, `curl`, `wget`, `jq` must be installed manually.
3. **Container 102 uses Debian, not Ubuntu** — The `proxmox-lxc-setup.sh` template was not used; container was created differently.
4. **Password SSH is disabled** — Container only accepts keys. Use `pct exec 102 -- bash` or Proxmox console.
5. **First startup takes ~50 seconds** — Paper remaps obfuscated code on first run. Normal behavior.
6. **Auto-start requires two levels**: `systemctl enable minecraft` (inside) AND `pct set 102 --onboot 1` (host).
7. **JVM heap auto-detects from container RAM** — Formula: `(total_MB - 1024) / 1024` with 1GB minimum.

## Credential Storage

| Location | What | How to Access |
|----------|------|---------------|
| `.env` (local, gitignored) | Proxmox host, IP, passwords | `cat .env` in repo root |
| macOS Keychain | `proxmox-minecraft`, `minecraft-ct102` | `security find-generic-password -s minecraft-ct102 -w` |
| Azure Key Vault | (optional) `dp-kv-deliverypilot` | `az keyvault secret show --name minecraft-root-password` |
| `proxmox-credentials-*.txt` | Generated by setup script | Local file, do not commit |

## Modification Guidelines for Agents

1. **Keep scripts POSIX-compliant where possible** — they run in minimal LXC containers.
2. **Never hardcode secrets** — generate passwords (like root password in LXC setup) and output them securely.
3. **Preserve idempotency in install-minecraft.sh** — always back up before overwriting.
4. **Use absolute paths** inside scripts (`/opt/minecraft/`), never relative paths for server operations.
5. **Update both README.md and AGENTS.md** when changing user-visible behavior.
6. **Update index.html** when architecture or steps change.
7. **Test paths**: Scripts are designed to be tested in order: setup -> install -> test -> manage.

## Git Workflow

- Branch: `main`
- All scripts should be executable (`chmod +x`)
- Commit message format: `[area] description` (e.g., `scripts: add backup retention`)
- Push to `origin main` after changes
