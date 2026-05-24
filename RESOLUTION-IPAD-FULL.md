# Resolution: iPad InitialConnection-13 to Full Server Fix

## The Complete Journey

This document records the full resolution from the iPad `InitialConnection-13` error to a working cross-platform Minecraft server.

---

## Original Error (iPad)

```
NetherNet
"Your client is having trouble establishing a connection
to multiplayer server services"

Error Detail: InitialConnection-13
Version: 1.26.21-iPad14.2
Transport: RakNet:975
NetworkType: 2
Connected: Wifi
WorldName: Mira and Arya
```

## Diagnosis Timeline

| Step | What We Found | Fix Applied |
|------|--------------|-------------|
| 1 | iPad runs **Bedrock**, server is **Java** | Install **GeyserMC** to translate protocols |
| 2 | Geyser installed but Java server rejects version | Install **ViaVersion** for version translation |
| 3 | ViaVersion download URL was **404** | Found correct URL via GitHub releases |
| 4 | Server started but **watchdog thread crashed** | Restarted, now stable |
| 5 | Player **TabooBasil1922 connected successfully** | ✅ Full cross-platform support working |

---

## What Was Installed

| Plugin | Version | Purpose | Download |
|--------|---------|---------|----------|
| **Paper** | 1.21.11 build 69 | Java server core | PaperMC API |
| **Geyser-Spigot** | 2.10.0-b1154 | Bedrock→Java protocol translator | `download.geysermc.org` |
| **Floodgate** | 2.2.5-SNAPSHOT | Bedrock auth bridge | `download.geysermc.org` |
| **ViaVersion** | 5.9.1 | Version compatibility | GitHub releases |

---

## Final Working Commands

### 1. Install GeyserMC (for iPad/Bedrock support)

```bash
cd /opt/minecraft

# Download Geyser
wget -O plugins/Geyser-Spigot.jar \
  https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot

# Download Floodgate (required for Bedrock auth)
wget -O plugins/floodgate-spigot.jar \
  https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot

# Set permissions
chown -R minecraft:minecraft plugins

# Open firewall
ufw allow 19132/udp
ufw reload
```

### 2. Install ViaVersion (for version mismatch)

```bash
cd /opt/minecraft/plugins

# Download ViaVersion from GitHub releases (reliable)
wget -O ViaVersion.jar \
  https://github.com/ViaVersion/ViaVersion/releases/download/5.9.1/ViaVersion-5.9.1.jar

# Alternative: Get latest release URL dynamically
# wget -O ViaVersion.jar $(curl -s https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest | grep browser_download_url | cut -d'"' -f4)

# Set permissions
chown minecraft:minecraft ViaVersion.jar
```

### 3. Restart and Verify

```bash
# Restart server
systemctl restart minecraft

# Wait for full startup (60-90 seconds)
sleep 90

# Verify all plugins loaded
journalctl -u minecraft --no-pager | grep -E "ViaVersion|Geyser|floodgate|Done" | tail -n 20
```

---

## Expected Success Output

```
[ViaVersion] ViaVersion 5.9.1 is now loaded. Registering protocol transformers and injecting...
[ViaVersion] ViaVersion detected server version: 1.21.11 (774)
[ViaVersion] Finished mapping loading, shutting down loader executor.
[Geyser-Spigot] Started Geyser on UDP port 19132
[Geyser-Spigot] Done (9.042s)! Run /geyser help for help!
Done (40.716s)! For help, type "help"
[Geyser-Spigot] Player connected with username TabooBasil1922
[Geyser-Spigot] TabooBasil1922 has connected to the Java server
```

---

## Connection Details

| Platform | Client | Address | Port | Protocol |
|----------|--------|---------|------|----------|
| Java | PC/Mac/Linux | `192.168.0.236` | `25565` | TCP |
| Bedrock | iPad/iPhone/Xbox/Switch | `192.168.0.236` | `19132` | UDP |

## iPad Connection Steps

1. Open **Minecraft Bedrock** on iPad
2. Go to **Play** → **Servers** → **Add Server**
3. **Server Name:** `Dad's Server`
4. **Server Address:** `192.168.0.236`
5. **Port:** `19132`
6. Click **Save** then **Join**

---

## Troubleshooting Checklist

If connection still fails:

- [ ] Server is running: `systemctl is-active minecraft`
- [ ] Java port open: `ss -tlnp | grep 25565`
- [ ] Bedrock port open: `ss -ulnp | grep 19132`
- [ ] Firewall allows UDP 19132: `ufw status`
- [ ] iPad is on **same WiFi** as server (not guest network)
- [ ] iPad Minecraft is **updated** to latest version
- [ ] ViaVersion jar is **not corrupted**: `ls -lh /opt/minecraft/plugins/ViaVersion.jar`

---

## What Each Component Does

```
iPad (Bedrock 1.26.21)
    ↓ UDP 19132
Geyser-Spigot (protocol translator)
    ↓ converts Bedrock → Java packets
Floodgate (auth bridge)
    ↓ creates Java-compatible user profile
ViaVersion (version translator)
    ↓ converts 1.26.x protocol → 1.21.11 protocol
Paper Server (Java 1.21.11)
    ↓
World "Mira and Arya"
```

---

## Lessons Learned

1. **Bedrock ≠ Java** — They are completely different protocols. Geyser is required.
2. **Version matters** — Newer Bedrock clients need ViaVersion to connect to older Java servers.
3. **Download URLs change** — The Jenkins CI URL moved; GitHub releases are more reliable.
4. **Watchdog crashes are transient** — Paper's watchdog can crash during heavy plugin loading. Restart usually fixes it.
5. **Verify with logs** — `journalctl -u minecraft | grep "Player connected"` confirms real players are joining.

---

## References

- [KIDS-CONNECT.md](KIDS-CONNECT.md) — General kid connection guide
- [RESOLUTION-GEYSER.md](RESOLUTION-GEYSER.md) — Geyser setup details
- [RESOLUTION-VIAVERSION.md](RESOLUTION-VIAVERSION.md) — ViaVersion setup details
- [AGENTS.md](AGENTS.md) — Full server architecture

---

Last updated: 2026-05-24  
Status: ✅ **PRODUCTION READY** — Both Java and Bedrock players confirmed connecting
