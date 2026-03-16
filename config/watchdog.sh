#!/bin/bash
# OpenClaw Gateway Watchdog
# Checks gateway and channel health, and restarts if degraded.
# Designed to run on macOS, Linux, and WSL.

set -u

if command -v openclaw >/dev/null 2>&1; then
    CLI="$(command -v openclaw)"
elif [ -x "/opt/homebrew/bin/openclaw" ]; then
    CLI="/opt/homebrew/bin/openclaw"
elif [ -x "/usr/local/bin/openclaw" ]; then
    CLI="/usr/local/bin/openclaw"
else
    echo "openclaw binary not found" >&2
    exit 1
fi

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/openclaw}"
LOG_FILE="$RUNTIME_DIR/watchdog.log"
LOCK_FILE="$RUNTIME_DIR/watchdog.lock"
NOTIFY_PHONE="${NOTIFY_PHONE:-}"
STALE_THRESHOLD_SECONDS="${STALE_THRESHOLD_SECONDS:-7200}"

mkdir -p "$RUNTIME_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$size" -gt 1048576 ]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
        fi
    fi
}

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        old_pid=$(cat "$LOCK_FILE" 2>/dev/null || true)
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            exit 0
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

trap release_lock EXIT
rotate_log
acquire_lock

check_channel_health() {
    local profile_flag="$1"
    local health_output

    health_output=$($CLI $profile_flag health 2>&1)
    if [ $? -ne 0 ]; then
        echo "health_cmd_failed"
        return 1
    fi

    if echo "$health_output" | grep -Eqi "whatsapp.*(failed|error|disconnected|timeout)"; then echo "whatsapp_down"; return 1; fi
    if echo "$health_output" | grep -Eqi "slack.*(failed|error|disconnected|timeout)"; then echo "slack_down"; return 1; fi
    if echo "$health_output" | grep -Eqi "telegram.*(failed|error|disconnected|timeout)"; then echo "telegram_down"; return 1; fi
    if echo "$health_output" | grep -Eqi "discord.*(failed|error|disconnected|timeout)"; then echo "discord_down"; return 1; fi

    echo "ok"
    return 0
}

check_log_freshness() {
    local log_path="$1"

    if [ ! -f "$log_path" ]; then
        echo "log_missing"
        return 1
    fi

    local now last_mod age
    now=$(date +%s)
    last_mod=$(stat -f%m "$log_path" 2>/dev/null || stat -c%Y "$log_path" 2>/dev/null || echo 0)
    age=$((now - last_mod))

    if [ "$age" -gt "$STALE_THRESHOLD_SECONDS" ]; then
        echo "log_stale_${age}s"
        return 1
    fi

    echo "fresh"
    return 0
}

restart_profile() {
    local profile_flag="$1"
    local label="$2"

    log "Restarting $label gateway"
    $CLI $profile_flag gateway stop >/dev/null 2>&1 || true
    sleep 3
    $CLI $profile_flag gateway install >/dev/null 2>&1 || true
    $CLI $profile_flag gateway start >/dev/null 2>&1 || true
    sleep 8

    local result
    result=$(check_channel_health "$profile_flag")
    if [ "$result" = "ok" ]; then
        log "$label gateway restarted successfully"
        return 0
    fi

    log "$label gateway restarted but is still degraded: $result"
    return 1
}

send_notification() {
    local message="$1"

    [ -z "$NOTIFY_PHONE" ] && return 0

    $CLI message send --channel whatsapp --to "$NOTIFY_PHONE" --message "$message" >/dev/null 2>&1 || \
        log "Failed to send notification"
}

check_and_fix_profile() {
    local profile_flag="$1"
    local label="$2"
    local log_path="$3"

    local result
    result=$(check_channel_health "$profile_flag")
    if [ "$result" != "ok" ]; then
        log "$label health check failed: $result"
        if restart_profile "$profile_flag" "$label"; then
            send_notification "[watchdog] $label was degraded ($result) and auto-restarted at $(date '+%H:%M')"
        else
            send_notification "[watchdog] $label is degraded ($result) and failed to recover"
        fi
        return
    fi

    if [ -n "$log_path" ]; then
        local freshness
        freshness=$(check_log_freshness "$log_path")
        if [ "$freshness" != "fresh" ]; then
            log "$label log stale ($freshness) despite healthy status"
            if restart_profile "$profile_flag" "$label"; then
                send_notification "[watchdog] $label was silently stale ($freshness) and auto-restarted at $(date '+%H:%M')"
            else
                send_notification "[watchdog] $label is silently stale ($freshness) and failed to recover"
            fi
        fi
    fi
}

check_and_fix_profile "" "main" "$HOME/.openclaw/logs/gateway.log"
# Example additional profile:
# check_and_fix_profile "--profile my-slack" "my-slack" "$HOME/.openclaw-my-slack/logs/gateway.log"
