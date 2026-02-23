#!/bin/bash
# =============================================================================
# Claude Code Container Entrypoint
# =============================================================================
# Sets up fp plugin on first run, then executes the command.
# =============================================================================

# Set up fp Claude plugin if not already configured
# The marker file is in the mounted .claude directory so it persists
FP_MARKER="/root/.claude/.fp-setup-complete"

if [ ! -f "$FP_MARKER" ]; then
    echo "Setting up fp Claude plugin..."
    fp setup claude 2>/dev/null && touch "$FP_MARKER" || true
fi

# Set up Svelte MCP server if not already configured
SVELTE_MCP_MARKER="/root/.claude/.svelte-mcp-setup-complete"

if [ ! -f "$SVELTE_MCP_MARKER" ]; then
    echo "Setting up Svelte MCP server..."
    node -e "
const fs = require('fs');
const p = '/root/.claude.json';
let c = {};
try { c = JSON.parse(fs.readFileSync(p, 'utf8')); } catch {}
if (!c.mcpServers) c.mcpServers = {};
if (!c.mcpServers.svelte) {
  c.mcpServers.svelte = {
    type: 'stdio',
    command: 'npx',
    args: ['-y', '@sveltejs/mcp'],
    env: {}
  };
  fs.writeFileSync(p, JSON.stringify(c, null, 2));
  console.log('Svelte MCP server configured.');
}
" && touch "$SVELTE_MCP_MARKER" || true
fi

# Execute the provided command (defaults to "claude")
exec "$@"
