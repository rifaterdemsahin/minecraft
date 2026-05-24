# Next Start Guide

How to turn on the Minecraft server after it has been shut down or the Proxmox host has rebooted.

## Quick Start (If You Remember Everything)

```bash
# On Proxmox host
ssh root@workstation
pct start 102

# Inside container (after 30 seconds)
pct exec 102 -- bash
systemctl status minecraft   # Should show active
ss -tlnp | grep 25565      # Should show LISTEN
```

Done! Connect with Minecraft Java to `192.168.0.236:25565`.

---

## Detailed Steps

### Step 1: Start the Proxmox Host

Ensure your Proxmox server is powered on and booted.

### Step 2: Start Container 102

On the Proxmox host (`root@workstation`):

```bash
# Check if container is already running
pct status 102

# If not running, start it
pct start 102

# Verify it started
pct status 102
```

### Step 3: Wait for Container Boot

Wait approximately 30 seconds for the container to fully boot and network to come up.

### Step 4: Verify Minecraft Auto-Started

Access the container and check:

```bash
# Enter container
pct exec 102 -- bash

# Check service status
systemctl status minecraft --no-pager

# Check port
ss -tlnp | grep 25565

# Or run the full test suite
cd /opt/minecraft/scripts
./test-boot.sh
```

### Step 5: Connect to Server

Open Minecraft Java Edition:
1. Go to **Multiplayer**
2. Click **Add Server**
3. Server Name: `Minecraft Server`
4. Server Address: `192.168.0.236:25565`
5. Click **Join Server**

---

## If Something Goes Wrong

### Container Won't Start

```bash
# On Proxmox host
pct start 102
# If error, check:
pct config 102 | grep onboot    # Should be 1
pct config 102 | grep memory     # Should be 4096 or higher
```

### Minecraft Service Not Running

```bash
# Inside container
systemctl start minecraft
systemctl status minecraft --no-pager
journalctl -u minecraft --no-pager -n 20
```

### Port 25565 Not Listening

```bash
# Inside container
ss -tlnp | grep 25565

# If empty, check logs for errors
journalctl -u minecraft -f

# Common fixes:
# - EULA not accepted: echo "eula=true" > /opt/minecraft/eula.txt
# - Java missing: apt-get install openjdk-21-jre-headless
# - Server JAR missing: re-run install-minecraft.sh
```

### Can't Connect from Minecraft Client

| Check | Command |
|-------|---------|
| Server running? | `systemctl is-active minecraft` |
| Port open? | `ss -tlnp \| grep 25565` |
| Firewall? | `ufw status` — should show 25565 ALLOW |
| Right IP? | `hostname -I` inside container |
| Network reachable? | Ping `192.168.0.236` from your PC |

---

## Where to Look for Help

| Document | Purpose |
|----------|---------|
| [AGENTS.md](AGENTS.md) | Full architecture, all scripts, troubleshooting table |
| [FORMULA.md](FORMULA.md) | Diagnosis checklist, common errors, log locations |
| [RESOLUTION.md](RESOLUTION.md) | Missing tools fix, manual install fallback |
| [RESOLUTION-PAPER-VERSION.md](RESOLUTION-PAPER-VERSION.md) | Paper version mismatch fix |
| [RESOLUTION-SERVER-STARTED.md](RESOLUTION-SERVER-STARTED.md) | Startup success reference |
| [index.html](index.html) | Web dashboard with architecture diagram |

---

## Auto-Start Checklist

Ensure these are set so the server starts automatically:

- [ ] Proxmox host boots automatically (BIOS power-on setting)
- [ ] Container `onboot=1` (`pct config 102 | grep onboot`)
- [ ] `systemctl is-enabled minecraft` returns `enabled`
- [ ] Boot symlink exists: `ls -la /etc/systemd/system/multi-user.target.wants/minecraft.service`

## Server Address

| Property | Value |
|----------|-------|
| IP Address | `192.168.0.236` |
| Port | `25565` |
| Full Address | `192.168.0.236:25565` |
| Container ID | `102` |
| Hostname | `minecraft-server` |

---

Last updated: 2026-05-24
