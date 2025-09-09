# Claude Desktop MCP Process Duplication Fix

## 🚀 TL;DR - Quick Fix

If Claude Desktop is using too much memory with MCPs:

1. Save this script as `~/fix-mcp.sh`:
```bash
#!/bin/bash
pkill -f "mcp"
sleep 2
open "/Applications/Claude.app"  # macOS
# For Linux: claude-desktop
# For Windows: start claude.exe
```

2. Run it whenever starting Claude
3. See below for permanent fix

## 🚨 Critical Issue

Claude Desktop has a severe bug causing MCP (Model Context Protocol) servers to spawn multiple instances and accumulate over time, leading to system instability and functionality breakage.

## ⚠️ Version Notice
Last tested with Claude Desktop v0.12.129 (September 2025)
Check if this issue is fixed in newer versions before applying workarounds.

### Affected Versions
- Confirmed: v0.12.129 on macOS
- Potentially: All recent versions
- Status on Windows/Linux: Unknown

## 📊 Problem Description

### The Bug
1. **Duplication on Launch**: Each MCP server spawns 2 instances instead of 1
2. **Process Leak on Restart**: Old processes aren't terminated when Claude Desktop restarts
3. **Exponential Accumulation**: Processes multiply with each restart (2x → 4x → 6x → 8x)

### Impact
- **Memory Leak**: System memory exhaustion
- **CPU Overload**: Multiple instances competing for resources
- **OAuth Failures**: Authentication-based MCPs fail due to token conflicts
- **Log Explosion**: Rapid log file growth (10+ MB per session)
- **System Instability**: Risk of system crash from process accumulation

### How to Check If You're Affected

```bash
# Count your MCP processes
ps aux | grep -E "mcp" | grep -v grep | wc -l

# Compare with the number of MCPs in your config
# If actual > configured, you're affected
```

## ✅ Solution

### Quick Fix: Process Cleanup Script

Kill all MCP processes before starting Claude Desktop:

```bash
#!/bin/bash
# cleanup-mcp.sh
# Generic MCP cleanup script

# Kill any process containing 'mcp' in its command
pkill -f "mcp"

# Also kill common npm/npx processes that might be MCP-related
pkill -f "npx.*@"
pkill -f "npm exec"

echo "MCP processes cleaned up"
```

### Permanent Solution: PID-Lock Wrapper

This universal wrapper ensures only ONE instance of each MCP can run:

```bash
#!/bin/bash
# mcp-single-instance.sh
# Universal wrapper preventing duplicate MCP processes

# Configuration
SCRIPT_NAME=$(basename "$0" .sh)
PIDFILE="/tmp/mcp-${SCRIPT_NAME}.pid"
LOGFILE="/tmp/mcp-${SCRIPT_NAME}.log"

# Check if already running
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "[$(date)] Already running with PID $OLD_PID" >> "$LOGFILE"
        exit 0
    else
        echo "[$(date)] Removing stale PID file" >> "$LOGFILE"
        rm -f "$PIDFILE"
    fi
fi

# Store current PID
echo $$ > "$PIDFILE"
echo "[$(date)] Starting with PID $$" >> "$LOGFILE"

# Cleanup on exit
cleanup() {
    echo "[$(date)] Shutting down PID $$" >> "$LOGFILE"
    rm -f "$PIDFILE"
}
trap cleanup EXIT INT TERM

# Execute the actual MCP command
exec "$@"
```

## 📦 Implementation Guide

### Step 1: Create Wrapper Directory

```bash
mkdir ~/mcp-wrappers
cd ~/mcp-wrappers
```

### Step 2: Create a Wrapper

#### Simple Version (Recommended for most users)

```bash
#!/bin/bash
# simple-mcp-wrapper.sh
# Simple single-instance wrapper

[ -f "/tmp/$(basename $0).pid" ] && exit 0
echo $$ > "/tmp/$(basename $0).pid"
trap "rm -f /tmp/$(basename $0).pid" EXIT
exec "$@"
```

#### Advanced Version (With logging)

```bash
#!/bin/bash
# generic-mcp-wrapper.sh
# Works for any MCP server with logging

# Get a unique name from the first argument or script name
MCP_NAME="${1:-$(basename $0 .sh)}"
PIDFILE="/tmp/${MCP_NAME}.pid"

# Check if already running
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        exit 0
    fi
fi

# Store PID and run
echo $$ > "$PIDFILE"
trap "rm -f $PIDFILE" EXIT

# Shift the name argument and execute the rest
shift
exec "$@"
```

### Step 3: Update Claude Desktop Configuration

Example `claude_desktop_config.json` structure:

```json
{
  "mcpServers": {
    "your-server-name": {
      "command": "/bin/bash",
      "args": [
        "/Users/YOUR_USERNAME/mcp-wrappers/generic-mcp-wrapper.sh",
        "your-server-name",
        "YOUR_ORIGINAL_COMMAND",
        "YOUR_ORIGINAL_ARGS"
      ]
    }
  }
}
```

### Step 4: Create Launch Script

```bash
#!/bin/bash
# launch-claude-safe.sh
# Safe launcher for Claude Desktop

echo "Cleaning up old MCP processes..."

# Generic cleanup - kills anything with 'mcp' in the process
pkill -f "mcp" 2>/dev/null

# Wait for processes to terminate
sleep 2

echo "Starting Claude Desktop..."
open "/Applications/Claude.app"

echo "Claude Desktop launched with clean MCP state"
```

## 🔍 Diagnostics

### Check Process Count

```bash
#!/bin/bash
# check-mcp-health.sh

echo "=== MCP Process Health Check ==="
echo "Total MCP processes: $(ps aux | grep -i mcp | grep -v grep | wc -l)"
echo ""
echo "Process details:"
ps aux | grep -i mcp | grep -v grep | awk '{print $2, $11}' | head -20
```

### Monitor Process Growth

```bash
#!/bin/bash
# monitor-mcp.sh

while true; do
    COUNT=$(ps aux | grep -i mcp | grep -v grep | wc -l)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] MCP processes: $COUNT"
    
    if [ $COUNT -gt 20 ]; then
        echo "WARNING: High MCP process count detected!"
    fi
    
    sleep 60
done
```

## 🛠️ Advanced Solutions

### Automatic Cleanup with LaunchAgent (macOS only)

Create `~/Library/LaunchAgents/com.user.mcp-cleanup.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mcp-cleanup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>pkill -f mcp</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

Load it: `launchctl load ~/Library/LaunchAgents/com.user.mcp-cleanup.plist`

### Automatic Cleanup with systemd (Linux only)

Create `~/.config/systemd/user/mcp-cleanup.service`:

```ini
[Unit]
Description=MCP Process Cleanup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pkill -f mcp

[Install]
WantedBy=default.target
```

Create `~/.config/systemd/user/mcp-cleanup.timer`:

```ini
[Unit]
Description=Run MCP cleanup every hour
Requires=mcp-cleanup.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

Enable it: `systemctl --user enable --now mcp-cleanup.timer`

### Automatic Cleanup with Task Scheduler (Windows only)

Create a batch file `mcp-cleanup.bat`:

```batch
@echo off
taskkill /F /IM *mcp* 2>nul
timeout /t 2 /nobreak >nul
start "" "C:\Path\To\Claude Desktop.exe"
```

Add to Task Scheduler:
1. Open Task Scheduler
2. Create Basic Task → "MCP Cleanup"
3. Trigger: "When I log on" or "Daily"
4. Action: Start `mcp-cleanup.bat`

### Process Limiter Script

```bash
#!/bin/bash
# limit-mcp-processes.sh
# Keeps MCP process count under control

MAX_MCP_PROCESSES=10

while true; do
    CURRENT=$(ps aux | grep -i mcp | grep -v grep | wc -l)
    
    if [ $CURRENT -gt $MAX_MCP_PROCESSES ]; then
        echo "Too many MCP processes ($CURRENT), cleaning up..."
        
        # Kill the oldest MCP processes
        ps aux | grep -i mcp | grep -v grep | \
            sort -k10 | head -n $((CURRENT - MAX_MCP_PROCESSES)) | \
            awk '{print $2}' | xargs kill 2>/dev/null
    fi
    
    sleep 300  # Check every 5 minutes
done
```

## 📊 Performance Metrics

### Expected vs Actual

| Metric | Expected | With Bug | After Fix |
|--------|----------|----------|-----------|
| Process Count | N | 2N → 4N → 8N | N |
| Memory Usage | 100MB per MCP | 400MB+ per MCP | 100MB per MCP |
| OAuth Success | 100% | 0-50% | 100% |
| CPU Usage | Normal | High | Normal |

## 🐛 Technical Analysis

### Why This Happens

1. **No PID Tracking**: Claude Desktop doesn't track spawned process IDs
2. **No Single-Instance Check**: Missing mutex/lock mechanism
3. **Improper Cleanup**: Exit handlers don't terminate child processes
4. **Race Conditions**: Multiple initialization attempts during startup

### Common Error Messages

If you see these in logs, you're likely affected:
- `Error: EADDRINUSE`
- `SSE stream disconnected`
- `Authentication failed: token already in use`
- `TypeError: terminated`

## 📝 Reporting the Issue

When reporting to Anthropic, include:

```markdown
Claude Desktop Version: [YOUR_VERSION]
OS: [YOUR_OS]
MCP Count: [NUMBER_OF_CONFIGURED_MCPS]
Process Count: $(ps aux | grep -i mcp | grep -v grep | wc -l)
Using Workaround: Yes/No
```

## ✅ How to Know It's Working

After implementing the fix:
- `ps aux | grep mcp | wc -l` should match your MCP count
- Memory usage should drop by 50-75%
- OAuth logins should work first time
- No "SSE stream disconnected" errors in logs

## 🤝 Community

### Confirm You're Affected

Download and review the diagnostic script:

```bash
# Download the script first
wget https://raw.githubusercontent.com/Cresnova/claude-desktop-mcp-fix/main/diagnose.sh
# Or using curl:
curl -o diagnose.sh https://raw.githubusercontent.com/Cresnova/claude-desktop-mcp-fix/main/diagnose.sh

# Review the script for safety
cat diagnose.sh

# Then run it
bash diagnose.sh
```

### Share Your Experience

Help others by sharing:
- Your Claude Desktop version
- Your operating system
- Whether this fix worked for you

## ⚠️ Important Notes

- This is a **community workaround**, not an official fix
- The bug affects **all MCP servers**, not specific ones
- Process accumulation is **exponential**, not linear
- OAuth-based services are **particularly affected**

## 📋 Quick Checklist

- [ ] Run diagnostic to confirm you're affected
- [ ] Implement the PID-lock wrapper
- [ ] Set up automatic cleanup
- [ ] Test with Claude Desktop restart
- [ ] Monitor process count over time

## 🔗 Resources

- [Model Context Protocol Docs](https://modelcontextprotocol.io)
- [Claude Desktop Support](https://support.anthropic.com)
- [Community Discussion](https://github.com/Cresnova/claude-desktop-mcp-fix/issues)

## 📄 License

MIT License - Use freely

---

**A community solution for a community problem**

⭐ Star this repo if it helped you!