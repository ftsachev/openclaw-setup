param(
    [string]$LogPath = "$env:TEMP\openclaw\watchdog.log"
)

$ErrorActionPreference = "Continue"

$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "[$timestamp] $Message"
}

function Test-GatewayReachable {
    try {
        $response = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:18789/ -TimeoutSec 5
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
    } catch {
        return $false
    }
}

function Test-GatewayPortListening {
    $conn = Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue
    return ($null -ne $conn)
}

Write-Log "Watchdog check starting..."

# Check if gateway port is listening
if (Test-GatewayPortListening) {
    Write-Log "Gateway port 18789 is listening"

    # Also try HTTP reachability
    if (Test-GatewayReachable) {
        Write-Log "Gateway is reachable via HTTP"
    } else {
        Write-Log "WARNING: Port is listening but HTTP not reachable (may be starting up)"
    }
} else {
    Write-Log "Gateway port not listening - attempting restart via openclaw..."
    try {
        $result = & openclaw gateway start 2>&1
        Write-Log "openclaw gateway start output: $result"

        Start-Sleep -Seconds 3

        if (Test-GatewayPortListening) {
            Write-Log "Gateway restarted successfully"
        } else {
            Write-Log "Gateway restart may have failed"
        }
    } catch {
        Write-Log "Failed to restart gateway: $_"
    }
}

Write-Log "Watchdog check complete"
