# Creative Mode Setup Guide

How to switch the Minecraft server from Survival to Creative Mode for Mira and Arya.

---

## Step 1: Stop the Server

```bash
systemctl stop minecraft
sleep 10
```

---

## Step 2: Edit server.properties

```bash
cd /opt/minecraft
nano server.properties
```

Find and change these lines:

```ini
# Change gamemode from survival to creative
gamemode=creative

# Optional: Set difficulty to peaceful
difficulty=0

# Optional: Disable PvP
pvp=false

# Optional: Set spawn protection to 0 (let them build anywhere)
spawn-protection=0
```

**To find the line quickly:**
```bash
grep -n "gamemode" /opt/minecraft/server.properties
```

---

## Step 3: Save and Exit

In nano:
1. Press `Ctrl + X`
2. Press `Y` (yes, save)
3. Press `Enter` (confirm filename)

---

## Step 4: (Optional) Reset/New World in Creative

If you want a fresh Creative world, back up the old one first:

```bash
# Backup survival world
mv /opt/minecraft/world /opt/minecraft/world-survival-backup

# New world will auto-generate in Creative mode on next start
```

Or **keep the current world** — it'll convert to Creative automatically.

---

## Step 5: Restart Server

```bash
systemctl start minecraft
sleep 90

# Verify Creative Mode is active
journalctl -u minecraft --no-pager | tail -20 | grep -i "gamemode\|loaded"
```

**Expected output:**
```
Default game type: CREATIVE
Done preparing level "world" (1.021s)
Done (41.591s)! For help, type "help"
```

**Full verification:**
```bash
ps aux | grep java | grep -v grep
ss -tlnp | grep 25565
journalctl -u minecraft --no-pager | tail -50 | grep -i "error\|exception\|failed"
```

**Expected:**
```
minecra+  3065  0.0 56.6 6063888 2375692 ?  Ssl  22:20  1:30 /usr/bin/java -Xms3G -Xmx3G -jar server.jar nogui
LISTEN 0  4096  *:25565  *:*  users:(("java",pid=3065,fd=141))
```

---

## Step 6: Verify in Game

When Mira and Arya connect, they should see:
- ✅ **Creative Mode** inventory (access all blocks)
- ✅ **Flight enabled** (double-tap jump)
- ✅ **No fall damage or hunger**

**Verify from server logs:**
```bash
journalctl -u minecraft --no-pager | grep -i "player connected\|creative"
```

**Expected output when player joins:**
```
[Geyser-Spigot] Player connected with username TabooBasil1922 (975)
[Geyser-Spigot] TabooBasil1922 (logged in as: TabooBasil1922) has connected to the Java server
[floodgate] Floodgate player logged in as .TabooBasil1922 joined (UUID: 00000000-0000-0000-0009-01f6559eda36)
.TabooBasil1922 joined the game
.TabooBasil1922[/192.168.0.81:0] logged in with entity id 96 at ([world]-421.69998, 68.00001, 282.6708)
```

**Player disconnect:**
```
[Geyser-Spigot] TabooBasil1922 has disconnected from the Java server because of Bedrock client disconnected
[floodgate] Floodgate player logged in as .TabooBasil1922 disconnected
.TabooBasil1922 lost connection: Disconnected
.TabooBasil1922 left the game
```

---

## Troubleshooting Connection Issues

If players can't connect after switching to Creative:

### Check Server is Running
```bash
ps aux | grep java | grep -v grep
ss -tlnp | grep 25565
systemctl is-active minecraft
```

### Check for Startup Errors
```bash
journalctl -u minecraft --no-pager | tail -50 | grep -i "error\|exception\|failed"
```

### Check Geyser (Bedrock/iPad)
```bash
ss -ulnp | grep 19132
journalctl -u minecraft --no-pager | grep -i "geyser\|started geyser"
```

### Common Fixes

| Problem | Cause | Fix |
|---------|-------|-----|
| "Connection timed out" | Firewall blocking | `ufw allow 25565/tcp && ufw allow 19132/udp` |
| "Connection refused" | Server not running | `systemctl start minecraft` |
| "Outdated server" | Version mismatch | Verify ViaVersion is loaded: `journalctl -u minecraft \| grep ViaVersion` |
| Can't break blocks at spawn | Spawn protection | Set `spawn-protection=0` in `server.properties` |
| World won't load | Corruption from gamemode change | Restore backup: `mv world-survival-backup world` |

### If World is Corrupted
```bash
# Stop server
systemctl stop minecraft

# Remove corrupted world
rm -rf /opt/minecraft/world

# Restore from backup
mv /opt/minecraft/world-survival-backup /opt/minecraft/world

# Or let it generate fresh (delete world folder, no backup)
# rm -rf /opt/minecraft/world

# Restart
systemctl start minecraft
```

---

## Quick Command (If Already Running)

You can also change gamemode **without restarting** using in-game commands:

```bash
# Via server console (if you have console access)
gamemode creative @a
```

Or via server console:
```bash
# Send command through screen or console
screen -S minecraft -p 0 -X stuff "gamemode creative @a$(printf \r)"
```

---

## Step 6: Verify in Game

When Mira and Arya connect, they should see:
- ✅ **Creative Mode** inventory (access all blocks)
- ✅ **Flight enabled** (double-tap jump)
- ✅ **No fall damage or hunger**

---

## Quick Command (If Already Running)

You can also change gamemode **without restarting** using in-game commands:

```bash
# Connect to server console and run:
gamemode creative @a
```

Or via server console:
```bash
# Send command through screen or console
screen -S minecraft -p 0 -X stuff "gamemode creative @a$(printf \r)"
```

---

## Creative Mode Settings Reference

| Setting | Value | Effect |
|---------|-------|--------|
| `gamemode` | `creative` | Infinite blocks, flight, no damage |
| `difficulty` | `0` / `peaceful` | No mobs, no hunger |
| `pvp` | `false` | Players can't hurt each other |
| `spawn-protection` | `0` | Can build at spawn point |
| `allow-flight` | `true` | Flight enabled (default in creative) |
| `max-build-height` | `256` | Default build limit |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Still in Survival after restart | Double-check `server.properties` has `gamemode=creative` |
| No flight | Press `F3+N` twice to toggle spectator then creative, or double-tap jump |
| Can't break blocks at spawn | Set `spawn-protection=0` |
| Inventory not showing all blocks | Press `E` — should show all blocks/tabs |

---

## References

- [AGENTS.md](AGENTS.md) — Server architecture
- [NEXT-START.md](NEXT-START.md) — How to turn on next time
- [KIDS-CONNECT.md](KIDS-CONNECT.md) — How Mira and Arya connect

---

Last updated: 2026-05-24
