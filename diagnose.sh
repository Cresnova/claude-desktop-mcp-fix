#!/bin/bash
# diagnose.sh - Claude Desktop MCP Health Check
# 
# This script checks if your Claude Desktop is affected by the MCP
# process duplication bug without making any changes to your system.

echo "Claude Desktop MCP Diagnostic Tool"
echo "=================================="
echo ""

# Detect OS
OS="Unknown"
CONFIG_PATH=""

if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    CONFIG_PATH="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
    CONFIG_PATH="$HOME/.config/Claude/claude_desktop_config.json"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    OS="Windows"
    CONFIG_PATH="$APPDATA/Claude/claude_desktop_config.json"
fi

echo "Operating System: $OS"
echo "Config Path: $CONFIG_PATH"
echo ""

# Count configured MCPs
if [ -f "$CONFIG_PATH" ]; then
    # Count the number of MCP server definitions
    CONFIGURED=$(grep -o '"mcpServers"' "$CONFIG_PATH" > /dev/null && grep -o '"[^"]*": {' "$CONFIG_PATH" | grep -v "mcpServers" | wc -l || echo 0)
    echo "Configured MCPs: $CONFIGURED"
    
    # List configured MCP names
    echo "MCP Names:"
    grep -o '"[^"]*": {' "$CONFIG_PATH" | grep -v "mcpServers" | sed 's/": {//g' | sed 's/"//g' | sed 's/^/  - /'
else
    echo "⚠️  Config file not found at expected location!"
    echo "    Looking for alternative locations..."
    
    # Try to find config file
    if [ "$OS" == "macOS" ]; then
        find ~/Library -name "claude_desktop_config.json" 2>/dev/null | head -5
    elif [ "$OS" == "Linux" ]; then
        find ~/.config -name "claude_desktop_config.json" 2>/dev/null | head -5
    fi
    CONFIGURED=0
fi

echo ""

# Count running MCP processes
echo "Checking running processes..."
RUNNING=$(ps aux 2>/dev/null | grep -i mcp | grep -v grep | grep -v diagnose.sh | wc -l)
NPM_RUNNING=$(ps aux 2>/dev/null | grep -E "npm.*exec|npx" | grep -v grep | wc -l)

echo "MCP-related processes: $RUNNING"
echo "NPM/NPX processes: $NPM_RUNNING"

# Show sample of running processes
if [ $RUNNING -gt 0 ]; then
    echo ""
    echo "Sample of running MCP processes:"
    ps aux | grep -i mcp | grep -v grep | grep -v diagnose.sh | head -5 | awk '{print "  PID " $2 ": " $11 " " $12}'
fi

echo ""
echo "DIAGNOSIS"
echo "---------"

# Calculate overhead
if [ $CONFIGURED -gt 0 ]; then
    EXPECTED=$CONFIGURED
    ACTUAL=$RUNNING
    
    if [ $ACTUAL -gt $EXPECTED ]; then
        OVERHEAD=$(( $ACTUAL - $EXPECTED ))
        RATIO=$(( $ACTUAL / $EXPECTED ))
        
        echo "❌ AFFECTED: You have MCP process duplication!"
        echo ""
        echo "   Expected processes: $EXPECTED"
        echo "   Actual processes:   $ACTUAL"
        echo "   Extra processes:    $OVERHEAD"
        echo "   Multiplication:     ${RATIO}x"
        echo ""
        echo "   This indicates the bug is active on your system."
        echo "   Apply the fix from the README to resolve this."
        
    elif [ $ACTUAL -eq $EXPECTED ]; then
        echo "✅ HEALTHY: Process count matches configuration"
        echo ""
        echo "   Your MCP processes are running normally."
        echo "   No duplication detected."
        
    else
        echo "⚠️  UNUSUAL: Fewer processes than expected"
        echo ""
        echo "   Expected: $EXPECTED"
        echo "   Running:  $ACTUAL"
        echo ""
        echo "   Some MCPs may not be running."
    fi
else
    if [ $RUNNING -gt 0 ]; then
        echo "⚠️  WARNING: MCP processes found but no config detected"
        echo ""
        echo "   Found $RUNNING MCP processes"
        echo "   Config file not found at expected location"
        echo ""
        echo "   This could mean:"
        echo "   1. Claude Desktop config is in a non-standard location"
        echo "   2. Orphaned MCP processes from previous sessions"
    else
        echo "ℹ️  No MCPs configured or running"
        echo ""
        echo "   If you expect MCPs to be running, check:"
        echo "   1. Claude Desktop is installed"
        echo "   2. MCPs are configured"
        echo "   3. Claude Desktop is running"
    fi
fi

echo ""
echo "MEMORY USAGE"
echo "------------"

# Check memory usage if possible
if command -v top > /dev/null 2>&1; then
    if [ "$OS" == "macOS" ]; then
        MEM_USAGE=$(ps aux | grep -i mcp | grep -v grep | awk '{sum += $4} END {printf "%.1f", sum}')
        echo "MCP processes using: ${MEM_USAGE}% of system memory"
    else
        MEM_USAGE=$(ps aux | grep -i mcp | grep -v grep | awk '{sum += $4} END {printf "%.1f", sum}')
        echo "MCP processes using: ${MEM_USAGE}% of system memory"
    fi
fi

echo ""
echo "RECOMMENDATIONS"
echo "---------------"

if [ $CONFIGURED -gt 0 ] && [ $ACTUAL -gt $EXPECTED ]; then
    echo "1. Kill all MCP processes: pkill -f mcp"
    echo "2. Implement the PID-lock wrapper from README"
    echo "3. Restart Claude Desktop using the safe launcher"
    echo ""
    echo "See: https://github.com/Cresnova/claude-desktop-mcp-fix"
fi

echo ""
echo "Report generated: $(date)"
echo "Share this output when reporting issues"