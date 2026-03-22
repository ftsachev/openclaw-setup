# OpenClaw Self-Heal System v3.0

**Adaptive healing with root cause analysis and predictive detection**

## Overview

The v3.0 self-heal system is a significant upgrade that transforms basic gateway recovery into an intelligent, learning health management system. It doesn't just restart things—it understands _why_ they failed and adapts its approach over time.

## What's New in v3.0

### 🧠 Adaptive Healing
- Learns from past failures to optimize retry delays
- Exponential backoff that adjusts based on success patterns
- After 10 consecutive successes, resets to default configuration

### 🔍 Root Cause Analysis
Automatically detects failure types:
| Type | Detection | Recommendation |
|------|-----------|----------------|
| **OOM** | Memory > 500MB | Check for memory leaks, reduce load |
| **Crash** | PID changed unexpectedly | Check logs, consider rebuild |
| **Network** | Port unreachable | Check firewall, port conflicts |
| **Disk** | Low free space | Free space, check log bloat |
| **Node.js** | Version < 18 or missing | Update Node.js runtime |
| **Unknown** | No specific cause | Manual investigation needed |

### 📈 Predictive Degradation
- Tracks response time trends over 100 health checks
- Detects degradation before complete failure
- Alerts when average response time exceeds thresholds
- Identifies degrading trends (1.5x increase over time)

### 📊 Health Metrics Tracking
- Response time measurement for every check
- Rolling average (last 10 checks)
- Trend analysis (stable/improving/degrading)
- JSON metrics file for external analysis

### 🚨 Escalation Logic
| Level | Trigger | Behavior |
|-------|---------|----------|
| 0 | Normal | Standard notifications |
| 1 | 3+ failures | Enhanced notifications |
| 2 | 5+ failures | Critical alerts |
| 3 | Circuit break | Emergency notification, cron disabled |

### 🔧 Dependency Checks
Before healing attempts, validates:
- **Disk space**: Minimum free space threshold
- **Node.js**: Version compatibility check
- **Port conflicts**: Detects non-OpenClaw processes on port 18789

### 📜 Failure Pattern Learning
- Tracks count of each failure type
- Identifies dominant failure pattern
- Provides targeted recommendations
- Maintains 50-entry failure history

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Self-Heal v3.0                           │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Predict    │  │    Detect    │  │     Heal     │      │
│  │  Degradation │→ │ Root Cause   │→ │   Adaptive   │      │
│  │              │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         ↓                  ↓                  ↓              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Metrics    │  │  Escalation  │  │   Circuit    │      │
│  │   Tracking   │  │   Logic      │  │   Breaker    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    ┌───────────────┐
                    │   Telegram    │
                    │  Notification │
                    └───────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `selfheal.ps1` | Main healing script (v3.0) |
| `selfheal_config.json` | Customizable configuration |
| `selfheal_state.json` | Current state and counters |
| `selfheal_metrics.json` | Health metrics history |
| `selfheal_history.json` | Failure history (last 50) |
| `selfheal.log` | Execution logs |

## Installation

### Step 1: Deploy Script

```powershell
powershell -Command "Copy-Item 'C:\Users\filip\dev\openclaw-setup\scripts\selfheal.ps1' 'C:\Users\filip\.openclaw\workspace\selfheal.ps1' -Force"
```

### Step 2: Create Configuration

```powershell
powershell -Command "Copy-Item 'C:\Users\filip\dev\openclaw-setup\config\selfheal_config.template.json' 'C:\Users\filip\.openclaw\workspace\selfheal_config.json'"
```

Edit with your Telegram credentials:
```powershell
notepad C:\Users\filip\.openclaw\workspace\selfheal_config.json
```

### Step 3: Update Cron Job

The cron job delivery mode must be `internal` (not `announce`):

```bash
# Via OpenClaw CLI
openclaw cron list --json
# Edit jobs.json directly if needed
```

## Configuration Reference

### Core Settings

```json
{
  "maxAttempts": 3,              // Gateway start attempts
  "initialRetryDelaySec": 30,    // Base retry delay
  "maxRetryDelaySec": 300,       // Max retry delay cap
  "circuitBreakThreshold": 5,    // Failures before disable
  "autoRecoverCircuitBreakHours": 4,  // Auto-recover time
  "notificationCooldownMin": 15  // Min minutes between alerts
}
```

### Notification Settings

```json
{
  "botToken": "YOUR_BOT_TOKEN",  // From @BotFather
  "chatId": "YOUR_CHAT_ID",      // Your user/chat ID
  "escalateAfterFailures": 3,    // When to start escalating
  "escalationChatId": ""         // Optional: different chat for critical
}
```

### Predictive Thresholds

```json
{
  "healthResponseTimeWarnMs": 1000,   // Warn if avg > 1s
  "healthResponseTimeCritMs": 5000    // Critical if avg > 5s
}
```

### Dependency Checks

```json
{
  "minFreeDiskMB": 100,      // Minimum free space
  "checkNodeHealth": true    // Check Node.js version
}
```

## How It Works

### Normal Operation (Healthy Gateway)

```
1. Run on schedule (every 30 min)
2. Check dependencies (disk, Node.js, port)
3. Test health endpoint (measure response time)
4. Record metrics (response time, status)
5. Analyze trends (stable/improving/degrading)
6. If healthy: log success, update counters, exit
7. If was previously down: send recovery notification
```

### Gateway Down - Healing Flow

```
1. DETECTION: Health endpoint not responding
2. ANALYSIS: Root cause analysis (OOM/crash/network/disk/nodejs)
3. PATTERN: Update failure pattern counts
4. NOTIFY: Send initial failure alert with root cause
5. LOG: Add to failure history

6. PHASE 1: Try gateway start (up to 3 attempts)
   - Adaptive delay between attempts
   - Stop existing processes
   - Fix permissions
   - Clean temp files
   - Run `openclaw gateway start`
   - Verify listener

7. PHASE 2: If start fails, run doctor (up to 2 attempts)
   - Run `openclaw doctor --fix`
   - Verify recovery

8. SUCCESS: 
   - Reset failure counters
   - Update adaptive config
   - Send recovery notification
   - Exit 0

9. FAILURE:
   - Increment failure count
   - Update adaptive config (increase delays)
   - Check escalation level
   - Send failure notification with recommendations
   - If threshold reached: trigger circuit breaker
   - Exit 1
```

### Circuit Breaker Flow

```
After 5 consecutive failures:
1. Set circuitBreakUntil timestamp (4 hours)
2. Increment escalation level
3. Send CRITICAL notification
4. Disable cron job via CLI
5. Auto-recover after timeout expires
```

## Metrics System

### Response Time Tracking

Every health check measures response time:
```json
{
  "timestamp": "2026-03-22T21:30:00.000Z",
  "responseTimeMs": 45.23,
  "status": "healthy",
  "gatewayPid": 4712
}
```

### Trend Detection

Analyzes last 10 checks:
- **Stable**: First 5 avg ≈ Last 5 avg (within 20%)
- **Degrading**: Last 5 avg > First 5 avg × 1.5
- **Improving**: Last 5 avg < First 5 avg × 0.8

### Metrics File

Location: `C:\Users\filip\.openclaw\workspace\selfheal_metrics.json`

```json
{
  "history": [...],           // Last 100 checks
  "avgResponseTimeMs": 52.3,  // Last 10 average
  "responseTimeTrend": "stable",
  "lastCheckAt": "2026-03-22T21:30:00.000Z",
  "degradationDetectedAt": null
}
```

## Escalation Levels

| Level | Name | Trigger | Notification Style |
|-------|------|---------|-------------------|
| 0 | Normal | 0-2 failures | Standard, cooldown applies |
| 1 | Elevated | 3-4 failures | Enhanced detail, includes recommendations |
| 2 | High | 5+ failures | Critical styling, may use escalation chat |
| 3 | Emergency | Circuit break | Force send, cron disabled |

## Failure Patterns

The system tracks failure types and provides recommendations:

```json
{
  "failurePatterns": {
    "oom": 2,
    "crash": 5,
    "network": 1,
    "disk": 0,
    "nodejs": 0,
    "unknown": 1
  }
}
```

Dominant pattern: **crash** (5 occurrences)
Recommendation: _"Check gateway logs for panic/exception. Consider gateway rebuild or update."_

## Usage Examples

### Manual Test Run

```powershell
# Normal run
powershell -ExecutionPolicy Bypass -File "C:\Users\filip\.openclaw\workspace\selfheal.ps1"

# Verbose output
powershell -ExecutionPolicy Bypass -File "...\selfheal.ps1" -Verbose

# No notifications (testing)
powershell -ExecutionPolicy Bypass -File "...\selfheal.ps1" -NoNotify

# Force run (skip cooldown, trigger predictive alerts)
powershell -ExecutionPolicy Bypass -File "...\selfheal.ps1" -ForceRun
```

### View Logs

```powershell
# Last 50 lines
Get-Content "C:\Users\filip\.openclaw\workspace\selfheal.log" -Tail 50

# Real-time follow (PowerShell 5+)
Get-Content "C:\Users\filip\.openclaw\workspace\selfheal.log" -Wait -Tail 20
```

### View Metrics

```powershell
# Current metrics
Get-Content "C:\Users\filip\.openclaw\workspace\selfheal_metrics.json" | ConvertFrom-Json

# Failure history
Get-Content "C:\Users\filip\.openclaw\workspace\selfheal_history.json" | ConvertFrom-Json

# State
Get-Content "C:\Users\filip\.openclaw\workspace\selfheal_state.json" | ConvertFrom-Json
```

### Reset State

```powershell
# Reset all counters
@{
    failures = 0
    consecutiveSuccesses = 0
    lastSuccessAt = (Get-Date).ToString('o')
    lastFailureAt = $null
    lastNotificationAt = $null
    totalRuns = 0
    totalHeals = 0
    gatewayPid = $null
    healthStatus = "healthy"
    lastFailureReason = $null
    lastHealMethod = $null
    circuitBreakUntil = $null
    escalationLevel = 0
    adaptiveRetryDelaySec = 30
    failurePatterns = @{
        "oom" = 0; "crash" = 0; "network" = 0
        "disk" = 0; "nodejs" = 0; "unknown" = 0
    }
} | ConvertTo-Json -Depth 10 | Set-Content "C:\Users\filip\.openclaw\workspace\selfheal_state.json"
```

## Troubleshooting

### Gateway Keeps Failing

1. Check logs for root cause:
   ```powershell
   Get-Content selfheal.log | Select-String "Root cause"
   ```

2. Review failure patterns:
   ```powershell
   (Get-Content selfheal_state.json | ConvertFrom-Json).failurePatterns
   ```

3. Check recommendations in state file

### Too Many Notifications

1. Increase cooldown:
   ```json
   {"notificationCooldownMin": 30}
   ```

2. Increase escalation threshold:
   ```json
   {"escalateAfterFailures": 5}
   ```

### Circuit Breaker Triggered

1. Wait for auto-recover (4 hours default), or
2. Manually reset:
   ```powershell
   $s = Get-Content selfheal_state.json | ConvertFrom-Json
   $s.circuitBreakUntil = $null
   $s.failures = 0
   $s | ConvertTo-Json | Set-Content selfheal_state.json
   ```

3. Re-enable cron job:
   ```bash
   openclaw cron enable <job-id>
   ```

### Predictive Alerts Not Working

1. Need at least 10 health checks for trend analysis
2. Check metrics file exists and has data
3. Verify thresholds in config

## Performance Impact

- **Memory**: ~5MB during execution
- **CPU**: <1% average
- **Disk**: ~100KB logs per day
- **Network**: 1-2 Telegram API calls per run

## Best Practices

1. **Set realistic thresholds**: Don't set response time warnings too low
2. **Monitor patterns**: Review failure history weekly
3. **Tune adaptively**: Let the system learn, but review config monthly
4. **Test after changes**: Use `-NoNotify` for initial testing
5. **Keep logs**: Rotate logs monthly for historical analysis

## Migration from v2.0

1. Backup existing state:
   ```powershell
   Copy-Item selfheal_state.json selfheal_state.json.bak
   ```

2. Replace script with v3.0

3. Update config with new options (or delete to auto-create)

4. Run manual test:
   ```powershell
   .\selfheal.ps1 -Verbose
   ```

5. Monitor first few automated runs

v3.0 is backward compatible with v2.0 state files—missing fields auto-initialize.

## Support

For issues or feature requests, check the logs first:
```powershell
Get-Content selfheal.log -Tail 100
```

Common issues and solutions are in the Troubleshooting section above.
