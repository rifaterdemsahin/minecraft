# Resolution: ViaVersion for Bedrock Client Version Mismatch

## Problem

Bedrock player connects but immediately disconnects with:
```
Outdated server! I'm still on 1.21.11
```

**Root Cause:** The iPad is running a newer Minecraft Bedrock version (likely 1.21.50+) while the Java server is on 1.21.11. Geyser can translate the protocol, but the Java server itself rejects the client version.

## Log Evidence
```
[Geyser-Spigot] Player connected with username TabooBasil1922
[Geyser-Spigot] TabooBasil1922 has disconnected from the Java server because of
Outdated server! I'm still on 1.21.11
```

## Solution: Install ViaVersion

ViaVersion is a plugin that allows newer clients to connect to older servers by translating the protocol.

### Quick Fix (Inside Container)

```bash
# Download ViaVersion (correct URL)
cd /opt/minecraft/plugins
wget -O ViaVersion.jar \
  https://ci.viaversion.com/job/ViaVersion/lastSuccessfulBuild/artifact/build/libs/ViaVersion-5.9.2-SNAPSHOT.jar

# Set permissions
chown minecraft:minecraft ViaVersion.jar

# Restart server
systemctl restart minecraft

# Wait for startup
sleep 60

# Verify ViaVersion loaded
journalctl -u minecraft --no-pager | grep -i "viaversion\|done" | tail -n 10
```

### Alternative: Update Paper Server

If you prefer not to use ViaVersion, update the server to latest:

```bash
cd /opt/minecraft/scripts
./install-minecraft.sh 1.21.50 Paper  # or whatever is latest
systemctl restart minecraft
```

But this may break existing world data or plugins.

## What ViaVersion Does

| Without ViaVersion | With ViaVersion |
|-------------------|-----------------|
| Java 1.21.11 client ✅ | Java 1.21.11-1.21.50 clients ✅ |
| Bedrock via Geyser ❌ (version mismatch) | Bedrock via Geyser ✅ (translated) |
| Older clients rejected | Newer clients accepted |

## Verify Fix

After installing ViaVersion and restarting:

```bash
# Check logs for ViaVersion loading
journalctl -u minecraft --no-pager | grep -i viaversion

# Should show:
# [ViaVersion] Loading ViaVersion vX.X.X
# [ViaVersion] Enabling ViaVersion vX.X.X

# Try connecting from iPad again
# Player should spawn in world successfully
```

## iPad Connection After Fix

1. Open Minecraft on iPad
2. Go to **Play** → **Servers**
3. Select `Dad's Server` (192.168.0.236:19132)
4. Click **Join**
5. Should now spawn in the world!

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Outdated server" still appears | Verify ViaVersion jar is in `/opt/minecraft/plugins/` and server was restarted |
| ViaVersion not loading | Check Java version: `java -version` — needs Java 21 |
| iPad still disconnects | Check `journalctl -u minecraft -f` for exact error |
| World looks weird | ViaVersion may not translate all blocks perfectly between major versions |

## References

- [ViaVersion Downloads](https://ci.viaversion.com/job/ViaVersion/)
- [ViaVersion Wiki](https://viaversion.com/)
- [RESOLUTION-GEYSER.md](RESOLUTION-GEYSER.md) — Geyser setup
- [KIDS-CONNECT.md](KIDS-CONNECT.md) — General connection guide

---

Last updated: 2026-05-24
