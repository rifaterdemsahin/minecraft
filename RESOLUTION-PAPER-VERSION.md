# Resolution: Paper Build Not Found for Version 1.21.4

## Problem

The `install-minecraft.sh` script failed with:
```
[ERROR] Could not find Paper build for version 1.21.4.
```

## Root Cause

PaperMC only keeps builds for actively supported Minecraft versions. Version `1.21.4` is no longer available in the Paper build API. The latest supported version is `1.21.11` (as of 2026-05-24).

## Immediate Fix (Inside Container)

Run the install script with the latest version:

```bash
# Inside container 102
/opt/minecraft/scripts/install-minecraft.sh 1.21.11 Paper
systemctl start minecraft
```

## Updated One-Liner for Fresh Install

```bash
apt-get update && apt-get install -y curl wget jq git ufw screen
mkdir -p /opt/minecraft/scripts && cd /opt/minecraft/scripts
curl -fsSL -o install-minecraft.sh https://raw.githubusercontent.com/rifaterdemsahin/minecraft/main/scripts/install-minecraft.sh
chmod +x install-minecraft.sh
./install-minecraft.sh 1.21.11 Paper
systemctl start minecraft
sleep 10
journalctl -u minecraft --no-pager -n 10
ss -tlnp | grep 25565
```

## How to Find Available Paper Versions

```bash
# List all supported versions
curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions[]'

# Get latest version
LATEST=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions | last')
echo "Latest Paper version: $LATEST"
```

## Prevention

The `install-minecraft.sh` script has been updated to:
1. Default to the latest Paper version if no version is specified
2. Show available versions if the requested version is not found

## References

- [PaperMC API Docs](https://docs.papermc.io/misc/downloads-api)
- [FORMULA.md](FORMULA.md) — General troubleshooting
- [AGENTS.md](AGENTS.md) — Architecture documentation
