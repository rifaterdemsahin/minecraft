# Kids Connection Guide: How to Play on Dad's Minecraft Server

> **Server Address:** `192.168.0.236:25565`  
> **Server Type:** Minecraft Java Edition (Paper 1.21.11)

---

## 🎮 Step-by-Step: Connect and Play

### Step 1: Open Minecraft Java Edition

Make sure you are using **Minecraft Java Edition**, not Bedrock/Console/Mobile.

- ✅ **Java Edition** = Computer (Windows, Mac, Linux)
- ❌ **Bedrock** = iPad, Xbox, PlayStation, Nintendo Switch, Phone

> **Important:** Java and Bedrock players **cannot** play together. You need Java Edition on a computer.

---

### Step 2: Go to Multiplayer

1. Click **"Multiplayer"** on the main menu
2. Click **"Add Server"**
3. Fill in:
   - **Server Name:** `Dad's Server` (or any name you like)
   - **Server Address:** `192.168.0.236:25565`
4. Click **"Done"**
5. Click the server name, then **"Join Server"**

---

### Step 3: Play!

If you see a green connection bar and "0/20 players", click **Join** and start building!

---

## ❌ Common Error: "Your client is having trouble establishing a connection to multiplayer server services"

This error usually means your computer **cannot reach the server** on the local network. Here's how to fix it:

---

## 🔧 Fixes (Try in Order)

### Fix 1: Check WiFi Network

| Question | What to Check |
|----------|---------------|
| Are you on the **same WiFi** as the server? | The server is on `192.168.0.xxx`. Your computer must also be on `192.168.0.xxx`. |
| Are you on **guest WiFi**? | Guest networks often block local devices. Switch to the main home WiFi. |
| Are you on **5GHz vs 2.4GHz**? | As long as it's the same router, this is fine. |

**How to check your IP:**
- **Windows:** Open Command Prompt, type `ipconfig`, look for "IPv4 Address"
- **Mac:** Open Terminal, type `ifconfig | grep inet`, look for `192.168.0.xxx`
- **Linux:** Open Terminal, type `ip addr`, look for `192.168.0.xxx`

Your IP should start with `192.168.0.` — if it starts with `192.168.1.` or `10.0.0.`, you may be on a different network or VLAN.

---

### Fix 2: Check if Server is Running

Ask dad to run this **inside the server container**:

```bash
pct exec 102 -- bash
systemctl is-active minecraft
ss -tlnp | grep 25565
```

Or run the test:
```bash
cd /opt/minecraft/scripts
./test-boot.sh
```

If the server is **not running**, dad should start it:
```bash
systemctl start minecraft
```

---

### Fix 3: Check Windows Firewall

Windows may be blocking Minecraft from accessing the local network.

**To fix:**
1. Open **Windows Security** → **Firewall & network protection**
2. Click **Allow an app through firewall**
3. Find **Java(TM) Platform SE binary** or **OpenJDK Platform binary**
4. Check both **Private** and **Public** boxes
5. Click **OK**

**Alternative:** Temporarily disable Windows Firewall to test:
1. Open **Windows Security** → **Firewall & network protection**
2. Click **Private network**
3. Turn **Microsoft Defender Firewall** to **Off**
4. Try connecting in Minecraft
5. **Turn it back On** after testing

If it works with firewall off, you need to add a rule for Java/Minecraft.

---

### Fix 4: Check Minecraft Account Type

| Account Type | Can Join LAN Servers? |
|--------------|----------------------|
| **Microsoft Account (paid)** | ✅ Yes |
| **Offline/Cracked** | ❌ No — must be logged in |
| **Demo account** | ❌ No — limited to demo worlds |

Make sure you are:
- Logged into your Microsoft/Mojang account
- Have purchased Minecraft Java Edition
- Are not in "Offline Mode"

---

### Fix 5: Restart Everything

Sometimes the network just needs a refresh:

1. **Quit Minecraft** completely (close the launcher too)
2. **Turn WiFi off and on** on your computer
3. **Wait 10 seconds**
4. **Reopen Minecraft** and try again

---

### Fix 6: Test with Ping

Open a command prompt/terminal and type:

```bash
ping 192.168.0.236
```

| Result | Meaning |
|--------|---------|
| `Reply from 192.168.0.236` | ✅ Network is working |
| `Request timed out` | ❌ Network blocked or server offline |
| `Destination host unreachable` | ❌ Wrong network or firewall blocking |

If ping fails, the problem is **network**, not Minecraft.

---

### Fix 7: Direct Connect (Bypass Server List)

Sometimes the server list has issues. Try **Direct Connect**:

1. In Minecraft Multiplayer, click **"Direct Connect"**
2. Type: `192.168.0.236:25565`
3. Click **"Join Server"**

This skips the server list ping and connects directly.

---

### Fix 8: Check for VPN or Proxy

If you have a **VPN** running (NordVPN, ExpressVPN, school VPN, etc.), it may route your traffic outside the local network.

**Fix:** Disconnect the VPN while playing on the local server.

---

## 🧒 Quick Checklist for Kids

Before asking dad for help, check these:

- [ ] I am on Minecraft **Java Edition** (not iPad/Xbox/Phone)
- [ ] I am on the **home WiFi** (not guest WiFi)
- [ ] I typed the address exactly: `192.168.0.236:25565`
- [ ] I restarted Minecraft
- [ ] I turned WiFi off and on
- [ ] I am logged into my Microsoft account
- [ ] I tried "Direct Connect" instead of "Add Server"

If all of these fail, **ask dad** to check if the server is running (see Fix 2 above).

---

## 👨‍💻 What Dad Should Check

If none of the kid fixes work, dad should verify:

```bash
# 1. Is the container running?
pct status 102

# 2. Is Minecraft running inside?
pct exec 102 -- systemctl is-active minecraft

# 3. Is the port listening?
pct exec 102 -- ss -tlnp | grep 25565

# 4. Is the firewall open?
pct exec 102 -- ufw status

# 5. Run full test
pct exec 102 -- bash -c "cd /opt/minecraft/scripts && ./test-boot.sh"
```

If the server is down:
```bash
pct exec 102 -- systemctl start minecraft
```

---

## 🎉 Success!

Once connected, you can:
- **Build** anything you want
- **Explore** the world dad generated
- **Play survival** together
- **Use commands** if dad made you an operator (`/op yourname`)

**Have fun! 🎮🏰🐷**

---

## ❌ iPad Error: "InitialConnection-13" (NetherNet)

If your kid is on an **iPad** and sees this error:

```
NetherNet
"Your client is having trouble establishing a connection 
to multiplayer server services"

Error Detail: InitialConnection-13
Version: 1.26.21-iPad14.2
WorldName: Mira and Arya
```

### ⚠️ The Real Problem

This is a **Minecraft Bedrock (iPad)** error. The server we built is **Java Edition**.

| Edition | Devices | Can Connect? |
|---------|---------|-------------|
| **Java** | Windows, Mac, Linux | ✅ Yes — this server |
| **Bedrock** | iPad, iPhone, Xbox, Switch, Android | ❌ No — different protocol |

**Java and Bedrock cannot play together.** Your kid needs Minecraft **Java Edition** on a computer.

### How to Fix

**Option 1: Get Java Edition (Recommended)**
- Buy Minecraft Java Edition for PC/Mac
- Log in with Microsoft account
- Add server: `192.168.0.236:25565`
- Works perfectly with this server

**Option 2: Run Bedrock-Compatible Server (Geyser)**
If you want iPad to connect, install GeyserMC:
```bash
# Inside container
cd /opt/minecraft
wget https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot
# Configure Geyser to listen on port 19132
# Restart server
```
Then iPad connects to `192.168.0.236:19132`

**Option 3: Use Minecraft Realms**
- Pay $4-8/month for official Bedrock Realms
- Works with iPad, Xbox, Switch, Phone
- No server setup needed

### iPad-Only Fixes (If Already on Correct Server Type)

If the error happens on a **Bedrock-compatible** server:

| Fix | Steps |
|-----|-------|
| **Force close app** | Swipe up, close Minecraft, wait 10s, reopen |
| **Toggle WiFi** | Airplane mode ON 5s, then OFF |
| **Check world host** | If joining "Mira and Arya", the host must be online |
| **Update Minecraft** | App Store → Updates → Minecraft |
| **Clear cache** | Settings → General → iPad Storage → Minecraft → Offload App → Reinstall |
| **Restart iPad** | Hold power button, slide to power off, turn on |

### What "InitialConnection-13" Means

| Code | Meaning |
|------|---------|
| `InitialConnection` | Failed at the very first network handshake |
| `-13` | Specific sub-error: likely network timeout or auth failure |

Common causes:
- WiFi blocking local connections (guest network)
- Minecraft auth servers down
- World host offline (for peer-to-peer worlds)
- Firewall blocking port 19132 (Bedrock default)

---

## Still Not Working?

Check these documents:
- [FORMULA.md](FORMULA.md) — General troubleshooting
- [RESOLUTION-SERVER-STARTED.md](RESOLUTION-SERVER-STARTED.md) — Server startup issues
- [AGENTS.md](AGENTS.md) — Full architecture and network details

Or ask dad to check the server logs:
```bash
pct exec 102 -- journalctl -u minecraft -f
```
