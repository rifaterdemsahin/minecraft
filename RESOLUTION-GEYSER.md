# Resolution: GeyserMC Setup for iPad/Bedrock Support

## Problem

Kids on **iPad** (Minecraft Bedrock) cannot connect to the **Java Edition** server at `192.168.0.236:25565`.

**Error:** `InitialConnection-13` — Bedrock and Java are incompatible protocols.

## Solution: GeyserMC

GeyserMC is a proxy that translates Bedrock protocol to Java protocol, allowing iPad/Xbox/Switch/Mobile players to join Java servers.

## Quick Setup (Inside Container)

```bash
# Already downloaded Geyser
mv /opt/minecraft/spigot /opt/minecraft/plugins/Geyser-Spigot.jar

# Download Floodgate (required for Bedrock auth)
wget -O /opt/minecraft/plugins/floodgate-spigot.jar \
  https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot

# Create plugins directory if not exists
mkdir -p /opt/minecraft/plugins

# Set permissions
chown -R minecraft:minecraft /opt/minecraft/plugins

# Open firewall for Bedrock UDP port
ufw allow 19132/udp
ufw reload

# Restart server
systemctl restart minecraft

# Wait 60 seconds for Geyser to generate config
sleep 60

# Verify config was created
cat /opt/minecraft/plugins/Geyser-Spigot/config.yml | grep -A 3 "bedrock:"
```

Or run the setup script:
```bash
cd /opt/minecraft
bash scripts/setup-geyser.sh
```

## What Was Downloaded

| File | Size | Purpose |
|------|------|---------|
| `Geyser-Spigot.jar` | 18MB | Bedrock-to-Java protocol translator |
| `floodgate-spigot.jar` | ~2MB | Bedrock account authentication bridge |

## Connection Details After Setup

| Platform | Address | Port | Protocol |
|----------|---------|------|----------|
| Java (PC/Mac) | `192.168.0.236` | `25565` | TCP |
| Bedrock (iPad/Xbox) | `192.168.0.236` | `19132` | UDP |

## iPad Connection Steps

1. Open Minecraft on iPad
2. Go to **Play** → **Servers** → **Add Server**
3. **Server Name:** `Dad's Server`
4. **Server Address:** `192.168.0.236`
5. **Port:** `19132`
6. Click **Save** then **Join**

## First-Time Notes

- **First Bedrock join may take 30 seconds** for account translation
- **No Microsoft account required** on Bedrock side (Floodgate handles it)
- **Java players see Bedrock players** with a `.` prefix on their names
- **All game features work:** building, redstone, combat, chat

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Unable to connect" on iPad | Check `ufw status` — UDP 19132 must be open |
| "Invalid IP" | Use `192.168.0.236` not `192.168.0.236:19132` in Bedrock UI |
| Java players can't join | Check port 25565 TCP is still open |
| Server won't start | Check logs: `journalctl -u minecraft -f` |
| Config not found | Wait 60s after restart, then check `/opt/minecraft/plugins/Geyser-Spigot/config.yml` |

## Verify Geyser is Running

```bash
# Inside container
# Wait at least 60 seconds after server restart!
cat /opt/minecraft/plugins/Geyser-Spigot/config.yml | grep -A 5 "bedrock:"

# Should show:
# bedrock:
#   address: 0.0.0.0
#   port: 19132

# Check if port is listening (UDP)
ss -ulnp | grep 19132

# Check server logs for Geyser loading
journalctl -u minecraft --no-pager | grep -i geyser
```

## Why Config Was Missing

Geyser generates its `config.yml` **after the first server start**, not during download. If you checked immediately after downloading, the file didn't exist yet because:

1. JAR was downloaded ✅
2. Server needs restart to load plugin ✅
3. Plugin generates config on first load ✅ (takes ~30-60s)
4. Then you can read config ✅

**Fix:** Wait 60 seconds after `systemctl restart minecraft`, then check the config.

## References

- [GeyserMC Wiki](https://wiki.geysermc.org/)
- [Floodgate Docs](https://wiki.geysermc.org/floodgate/)
- [KIDS-CONNECT.md](KIDS-CONNECT.md) — General kid connection guide
- [AGENTS.md](AGENTS.md) — Server architecture

---

Last updated: 2026-05-24
