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
