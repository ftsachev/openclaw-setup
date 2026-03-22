# OpenClaw Self-Heal System

Version 2.0 - Smart healing with intelligent notifications

## Overview

The self-heal system automatically detects and recovers from OpenClaw gateway failures, with smart Telegram notifications that respect cooldowns and only alert on state changes.

## Components

### 1. selfheal.ps1 (Windows/WSL)

Main healing script for Windows environments. Run via cron job or Scheduled Task.

**Features:**
- Health endpoint monitoring
- Automatic gateway restart
- Device permission fixing
- Circuit breaker (disables after N consecutive failures)
- Smart Telegram notifications with cooldown
- Configurable thresholds via JSON

**Usage:**
```powershell
# Basic run
powershell -ExecutionPolicy Bypass -File "C:\Users\filip\.openclaw\workspace\selfheal.ps1"

# Verbose mode
powershell -ExecutionPolicy Bypass -File "...\selfheal.ps1" -Verbose

# No notifications
powershell -ExecutionPolicy Bypass -File "...\selfheal.ps1" -NoNotify
```

### 2. selfheal_config.json

Configuration file for customizing behavior.

**Location:** `C:\Users\filip\.openclaw\workspace\selfheal_config.json`

**Options:**
```json
{
  "maxAttempts": 3,              // Gateway start attempts before giving up
  "retryDelaySec": 60,           // Seconds between retry attempts
  "circuitBreakThreshold": 5,    // Failures before disabling cron job
  "notificationCooldownMin": 15, // Minutes between Telegram notifications
  "botToken": "YOUR_BOT_TOKEN",  // Telegram bot token
  "chatId": "YOUR_CHAT_ID"       // Telegram chat ID for alerts
}
```

### 3. watchdog.sh (macOS/Linux/WSL)

System-level watchdog that monitors gateway and channel health.

**Features:**
- Multi-channel health checks (Telegram, WhatsApp, Slack, Discord)
- Automatic profile restart on degradation
- Stale log detection
- Telegram and WhatsApp notifications
- Cooldown-based alerting

**Environment Variables:**
```bash
NOTIFY_PHONE=""              # WhatsApp number for alerts
NOTIFY_TELEGRAM=""           # Telegram username for alerts
TELEGRAM_BOT_TOKEN=""        # Bot token for direct API calls
TELEGRAM_CHAT_ID=""          # Chat ID for Telegram notifications
NOTIFY_COOLDOWN_MIN=15       # Minutes between notifications
STALE_THRESHOLD_SECONDS=7200 # Log staleness threshold (2 hours)
```

### 4. watchdog.ps1 (Windows wrapper)

Windows wrapper that invokes the WSL watchdog script.

**Usage:**
```powershell
# Basic run
.\watchdog.ps1 -Distro "FedoraLinux"

# With Telegram notifications
.\watchdog.ps1 -NotifyOnFailure
```

## Installation

### Step 1: Copy selfheal.ps1 to workspace

```powershell
Copy-Item "C:\Users\filip\dev\openclaw-setup\scripts\selfheal.ps1" `
          "C:\Users\filip\.openclaw\workspace\selfheal.ps1"
```

### Step 2: Create configuration

```powershell
# Copy template
Copy-Item "C:\Users\filip\dev\openclaw-setup\config\selfheal_config.template.json" `
          "C:\Users\filip\.openclaw\workspace\selfheal_config.json"

# Edit with your Telegram credentials
notepad "C:\Users\filip\.openclaw\workspace\selfheal_config.json"
```

### Step 3: Create cron job

```bash
# Open OpenClaw and create the cron job
openclaw cron create --name "selfheal:gateway-port-18789" \
  --schedule "every 30m" \
  --command "powershell -ExecutionPolicy Bypass -File \"C:\Users\filip\.openclaw\workspace\selfheal.ps1\""
```

Or use the OpenClaw UI to create a scheduled job that runs every 30 minutes.

## How It Works

### Normal Operation (Gateway Healthy)

1. Self-heal runs on schedule
2. Checks `http://localhost:18789/health`
3. If healthy: logs success, resets failure counter, exits
4. If was previously down: sends recovery notification

### Gateway Down - Healing Flow

1. **Detection**: Health endpoint not responding
2. **Phase 1**: Try to start gateway (up to 3 attempts)
   - Stop any existing gateway processes
   - Fix device permissions
   - Clean up temp files
   - Run `openclaw gateway start`
   - Wait and verify
3. **Phase 2**: If start fails, run `openclaw doctor --fix` (up to 2 attempts)
4. **Success**: Reset failure counter, send recovery notification
5. **Failure**: Increment failure counter, send failure notification

### Circuit Breaker

After 5 consecutive failures:
- Sends critical alert to Telegram
- Disables the cron job automatically
- Requires manual intervention

This prevents infinite failure loops and notification spam.

## Notification Logic

### When Notifications Are Sent

✅ Gateway goes DOWN (first detection)
✅ Gateway recovers after being down
✅ Healing attempts in progress (retry notifications)
✅ Healing completely failed
✅ Circuit breaker triggered

### When Notifications Are Skipped

❌ Normal healthy check (no spam)
❌ Within cooldown period (15 min default)
❌ `-NoNotify` flag specified

## Troubleshooting

### Check logs

```powershell
Get-Content "C:\Users\filip\.openclaw\workspace\selfheal.log" -Tail 50
```

### Check state

```powershell
Get-Content "C:\Users\filip\.openclaw\workspace\selfheal_state.json"
```

### Manual test run

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\filip\.openclaw\workspace\selfheal.ps1" -Verbose
```

### Check cron job status

```bash
openclaw cron list
openclaw cron list --json
```

### Disable self-heal

```bash
# Find job ID
openclaw cron list --json

# Disable
openclaw cron disable <job-id>
```

### Re-enable self-heal

```bash
openclaw cron enable <job-id>
```

## State File Fields

```json
{
  "failures": 0,              // Consecutive failures
  "lastSuccessAt": "...",     // ISO timestamp of last success
  "lastFailureAt": "...",     // ISO timestamp of last failure
  "lastNotificationAt": "...",// ISO timestamp of last Telegram alert
  "totalRuns": 42,            // Total executions
  "totalHeals": 3,            // Successful recoveries
  "gatewayPid": 12345,        // Current gateway PID
  "healthStatus": "healthy"   // Current status
}
```

## Best Practices

1. **Set reasonable cooldown**: 15-30 minutes prevents notification fatigue
2. **Monitor circuit breaker**: If triggered, investigate root cause
3. **Check logs regularly**: Self-heal logs provide diagnostic info
4. **Test after setup**: Manually run once to verify Telegram works
5. **Update credentials**: Keep bot token and chat ID current

## Migration from v1

If you have an existing self-heal setup:

1. Stop existing cron job
2. Backup state file
3. Replace selfheal.ps1 with v2
4. Create selfheal_config.json (or let it auto-create with defaults)
5. Re-enable cron job
6. Test with manual run

The v2 script is backward compatible with existing state files.
