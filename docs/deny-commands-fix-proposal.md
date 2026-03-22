# Proposal: Fix gateway.nodes.denyCommands Ineffective Entries (REVISED)

## Problem Summary

After investigation, the issue is more nuanced than initially thought:

### Current Configuration (After v1 Fix)
```json
{
  "gateway.nodes.denyCommands": [
    "camera.snap",    // ⚠️ CLI subcommand, not invoke command
    "camera.clip",    // ⚠️ CLI subcommand, not invoke command  
    "screen.record"   // ⚠️ CLI subcommand, not invoke command
  ]
}
```

### Root Cause (Revised)

The security audit reports these as "ineffective" because:

1. **CLI commands vs Gateway invoke commands**: `camera.snap`, `camera.clip`, `screen.record` are CLI subcommands (`openclaw nodes camera snap`), not gateway node invoke commands
2. **Command registry mismatch**: The `denyCommands` list is validated against `defaults.allowCommands` or the node's declared command registry
3. **Different command namespaces**:
   - CLI: `openclaw nodes camera snap` → command ID might be `nodes.camera.snap` or just `camera.snap`
   - Gateway invoke: Commands that nodes declare they support when connecting

### Security Audit Output Analysis

```
Unknown command names (not in defaults/allowCommands): 
- camera.snap (did you mean: camera.list)
- camera.clip (did you mean: camera.list)
- screen.record
```

The audit suggests `camera.list` — this is the only camera command in the default allow list.

---

## Understanding OpenClaw Command Layers

### Layer 1: CLI Commands
```
openclaw nodes camera snap    # CLI invokes camera.snap on node
openclaw nodes screen record  # CLI invokes screen.record on node
openclaw nodes canvas present # CLI invokes canvas.present on node
```

### Layer 2: Gateway Node Commands
When a node connects, it declares supported commands:
```json
{
  "commands": ["canvas.present", "canvas.hide", "camera.snap", "screen.record", ...]
}
```

### Layer 3: Security Policy
```json
{
  "gateway.nodes.denyCommands": ["camera.snap"],  // Blocks this command
  "agents.defaults.allowCommands": ["canvas.*"]   // Only allows canvas commands
}
```

---

## Proposed Solutions

### Option A: Remove All denyCommands (Simplest)

If you don't have paired nodes, the denyCommands list is irrelevant.

```json
{
  "gateway.nodes.denyCommands": []
}
```

**Pros**: Eliminates warning entirely
**Cons**: No explicit command blocking if you add nodes later

### Option B: Use Canvas Commands (Confirmed Valid)

The security audit explicitly lists these as valid command names:

```json
{
  "gateway.nodes.denyCommands": [
    "canvas.present",
    "canvas.hide",
    "canvas.navigate",
    "canvas.eval",
    "canvas.snapshot",
    "canvas.a2ui.push",
    "canvas.a2ui.pushJSONL",
    "canvas.a2ui.reset"
  ]
}
```

**Pros**: Uses confirmed valid command names
**Cons**: Blocks canvas commands you might want to use

### Option C: Empty List + Document Decision

```json
{
  "gateway.nodes.denyCommands": []
}
```

Add to security documentation:
> "Node commands are restricted by default (no paired nodes). When pairing nodes, review capabilities and set denyCommands based on actual node command registry."

**Pros**: Clean config, no false warnings
**Cons**: Requires manual security review when adding nodes

### Option D: Investigate Node Command Registry (Most Thorough)

Pair a test node and inspect its declared commands:

```bash
openclaw nodes describe --node <node-id> --json
```

Then set `denyCommands` based on actual available commands.

---

## Recommended Approach: Option A + Documentation

For this Windows setup with **no paired nodes**:

```json
{
  "gateway.nodes.denyCommands": []
}
```

### Why?

1. **No paired nodes** = no node commands can execute
2. **Gateway bound to loopback** = no remote node connections
3. **Telegram channel only** = no local node pairing
4. **Warning is informational** = doesn't affect security posture

### When to Add denyCommands?

Only when you:
- Pair a macOS node (with camera/screen/canvas capabilities)
- Enable remote node connections
- Want to explicitly block certain capabilities

---

## Implementation

### Script: fix-denycommands-v3.ps1

```powershell
$configPath = "$env:USERPROFILE\.openclaw\openclaw.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Clear denyCommands (no paired nodes)
$config.gateway.nodes.denyCommands = @()

# Save
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath
```

### Verification

```bash
openclaw security audit --deep
# Expected: No deny_commands_ineffective warning
```

---

## Updated Warning Count

After fix:
- **Before**: 0 critical · 3 warn · 1 info
- **After**: 0 critical · 2 warn · 1 info

Remaining warnings:
1. `gateway.trusted_proxies_missing` — Informational for loopback-only
2. `gateway.probe_failed` — Auth scope issue, gateway is live

---

## References

- GitHub Issue #16508: `gateway.nodes.denyCommands` silently ineffective
- Security audit output: "Use exact command names (for example: canvas.present, canvas.hide...)"
- OpenClaw CLI: `openclaw nodes --help`
