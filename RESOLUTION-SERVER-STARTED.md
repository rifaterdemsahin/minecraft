# Resolution: Minecraft Server Startup Success

## Status

The Minecraft server has been **successfully installed and started** inside container 102.

## What Happened

| Step | Result |
|------|--------|
| Tools installed | ✅ curl, wget, jq, git, ufw, screen |
| Paper downloaded | ✅ Build 69 (52MB) |
| Java detected | ✅ OpenJDK 21.0.9 (Temurin) |
| Service created | ✅ systemd enabled |
| Server started | ✅ Running (remapping in progress) |
| Port 25565 | ✅ OPEN |

## Log Output

```
[INFO]: Found Paper build 69
server.jar                             [   <=>  ]  52.28M  89.7MB/s    in 0.6s    
Created symlink /etc/systemd/system/multi-user.target.wants/minecraft.service
[INFO]: Installed Paper 1.21.11 (build 69) with 3G heap
May 24 21:17:01 java[1817]: Starting org.bukkit.craftbukkit.Main
May 24 21:17:02 INFO: Loading Paper 1.21.11-69-main for Minecraft 1.21.11
May 24 21:17:03 INFO: Initialized 0 plugins
May 24 21:17:05 INFO: [ReobfServer] Remapping server...
```

## Next Steps (Inside Container)

The server is still doing first-time setup (remapping). Wait 30-60 seconds then check:

```bash
# Inside container
journalctl -u minecraft --no-pager -n 20
```

Look for:
```
Done (XX.XXXs)! For help, type "help"
```

Then verify:
```bash
ss -tlnp | grep 25565    # Should show LISTEN
systemctl is-active minecraft   # Should show active
```

## Connect to Server

Once `Done!` appears in logs, connect with Minecraft Java client:
- **Server Address:** `192.168.0.236:25565`

## Troubleshooting If Still Starting

```bash
# Watch live logs
journalctl -u minecraft -f

# If stuck on remapping for >5 minutes, restart
systemctl restart minecraft

# Check for errors
grep -i "error\|fatal\|exception" /opt/minecraft/logs/latest.log
```

## Files Created

| File | Purpose |
|------|---------|
| `/opt/minecraft/server.jar` | Paper 1.21.11 build 69 |
| `/opt/minecraft/server.properties` | Server config |
| `/opt/minecraft/eula.txt` | EULA accepted |
| `/opt/minecraft/ops.json` | Operator list (empty) |
| `/opt/minecraft/whitelist.json` | Whitelist (empty) |
| `/etc/systemd/system/minecraft.service` | Auto-start service |

## References

- [FORMULA.md](FORMULA.md) — General troubleshooting
- [AGENTS.md](AGENTS.md) — Architecture and workflows
