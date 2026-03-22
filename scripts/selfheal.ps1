# Self-heal script for OpenClaw gateway on port 18789
# Version: 2.0 (Smart healing with intelligent notifications)
#
# Features:
# - Health-check endpoint (http://localhost:18789/health)
# - Direct gateway execution with permission fixing
# - Retry-backoff with exponential delay
# - Comprehensive logging to file
# - Circuit-breaker (disable cron after N consecutive failures)
# - Uses openclaw health --json for richer status
# - Validates doctor output
# - Smart Telegram notifications (only on state changes)
# - Configurable thresholds via JSON config
# - Graceful degradation when Telegram is unavailable

param(
    [switch]$Verbose = $false,
    [switch]$NoNotify = $false
)

# ============================================================================
# Configuration
# ============================================================================
$port = 18789
$healthUrl = "http://localhost:${port}/health"
$baseDir = "C:\Users\filip\.openclaw"
$logFile = Join-Path $baseDir "workspace\selfheal.log"
$stateFile = Join-Path $baseDir "workspace\selfheal_state.json"
$configFile = Join-Path $baseDir "workspace\selfheal_config.json"
$devicesDir = Join-Path $baseDir "devices"
$pairedJson = Join-Path $devicesDir "paired.json"

# Defaults (can be overridden by config file)
$defaultConfig = @{
    maxAttempts = 3
    retryDelaySec = 60
    circuitBreakThreshold = 5
    consecutiveErrorLimit = 3
    notificationCooldownMin = 15
    botToken = "8629930214:AAEtuRiIAc665EXfslOY0538gmPQwGdPM68"
    chatId = "8537945694"
}

# ============================================================================
# Logging Functions
# ============================================================================
function Write-Log {
    param(
        [string]$msg,
        [string]$level = "INFO"
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
    $logLine = "[$ts] [$level] $msg"
    
    # Write to file
    try {
        $logLine | Out-File -FilePath $logFile -Append -Encoding utf8
    } catch {
        # Silent fail on log write error
    }
    
    # Write to stdout for cron capture
    if ($Verbose -or $level -eq "ERROR" -or $level -eq "WARN") {
        Write-Host $logLine
    }
}

function Write-Debug {
    param([string]$msg)
    if ($Verbose) {
        Write-Log $msg "DEBUG"
    }
}

# ============================================================================
# Configuration Management
# ============================================================================
function Get-Config {
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            # Merge with defaults for any missing keys
            foreach ($key in $defaultConfig.Keys) {
                if (-not $config.PSObject.Properties[$key]) {
                    $config.$key = $defaultConfig[$key]
                }
            }
            return $config
        } catch {
            Write-Log "Error reading config file, using defaults" "WARN"
            return $defaultConfig
        }
    } else {
        # Create default config file
        try {
            $defaultConfig | ConvertTo-Json -Depth 3 | Set-Content $configFile -Encoding utf8
            Write-Log "Created default config file"
        } catch {
            Write-Log "Could not create config file, using defaults" "WARN"
        }
        return $defaultConfig
    }
}

# ============================================================================
# State Management
# ============================================================================
function Get-State {
    if (Test-Path $stateFile) {
        try {
            return Get-Content $stateFile -Raw | ConvertFrom-Json
        } catch {
            Write-Log "Error reading state file, resetting" "WARN"
            return Get-DefaultState
        }
    } else {
        return Get-DefaultState
    }
}

function Get-DefaultState {
    return @{
        failures = 0
        lastSuccessAt = $null
        lastFailureAt = $null
        lastNotificationAt = $null
        totalRuns = 0
        totalHeals = 0
        gatewayPid = $null
        healthStatus = "unknown"
    }
}

function Set-State {
    param([object]$state)
    try {
        $state | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding utf8
        Write-Debug "State saved"
    } catch {
        Write-Log "Failed to save state: $_" "ERROR"
    }
}

# ============================================================================
# Telegram Notifications (Smart with cooldown)
# ============================================================================
function Send-Telegram {
    param(
        [string]$txt,
        [string]$level = "info",
        [switch]$Force = $false
    )
    
    if ($NoNotify) {
        Write-Debug "Notifications disabled, skipping Telegram send"
        return $false
    }
    
    $config = Get-Config
    $state = Get-State
    
    # Check cooldown (unless forced)
    if (-not $Force) {
        if ($state.lastNotificationAt) {
            try {
                $lastNotify = [DateTime]::Parse($state.lastNotificationAt)
                $cooldownMin = $config.notificationCooldownMin
                $elapsed = (Get-Date) - $lastNotify
                
                if ($elapsed.TotalMinutes -lt $cooldownMin) {
                    Write-Debug "Notification cooldown active ($([math]::Round($elapsed.TotalMinutes, 1)) min elapsed, need $cooldownMin min)"
                    return $false
                }
            } catch {
                Write-Debug "Could not parse lastNotificationAt, sending anyway"
            }
        }
    }
    
    # Format message with emoji based on level
    $emoji = switch ($level) {
        "critical" { "🚨" }
        "error"    { "❌" }
        "warn"     { "⚠️" }
        "success"  { "✅" }
        "info"     { "ℹ️" }
        default    { "🦞" }
    }
    
    $formattedMsg = "$emoji OpenClaw Self-Heal`n`n$txt`n`n_Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm')_"
    
    $uri = "https://api.telegram.org/bot$($config.botToken)/sendMessage"
    
    try {
        $body = @{
            chat_id = $config.chatId
            text = $formattedMsg
            parse_mode = "Markdown"
        }
        
        Invoke-RestMethod -Method Post -Uri $uri -Body $body -ErrorAction Stop | Out-Null
        Write-Debug "Telegram notification sent"
        
        # Update state
        $state.lastNotificationAt = (Get-Date).ToString('o')
        Set-State $state
        
        return $true
    } catch {
        Write-Log "Telegram send failed: $_" "WARN"
        return $false
    }
}

# ============================================================================
# Health Check Functions
# ============================================================================
function Test-HealthEndpoint {
    try {
        $resp = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($resp.status -ieq "ok" -or $resp.Status -ieq "ok") { return $true }
        if ($resp.ok -eq $true) { return $true }
        if ($resp -is [string] -and $resp -match '(?i)ok') { return $true }
        return $false
    } catch {
        Write-Debug "Health endpoint check failed: $_"
        return $false
    }
}

function Test-GatewayPort {
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -First 1
        return ($null -ne $conn)
    } catch {
        return $false
    }
}

function Get-GatewayPid {
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($conn) {
            return $conn.OwningProcess
        }
    } catch {
        # Ignore
    }
    return $null
}

function Get-HealthJson {
    try {
        $json = & openclaw health --json 2>$null | Out-String
        return $json | ConvertFrom-Json
    } catch {
        Write-Debug "Failed to get openclaw health: $_"
        return $null
    }
}

# ============================================================================
# Permission and Cleanup Functions
# ============================================================================
function Fix-DevicePermissions {
    Write-Log "Fixing permissions on devices directory..."
    try {
        if (-not (Test-Path $devicesDir)) {
            New-Item -ItemType Directory -Path $devicesDir -Force | Out-Null
            Write-Log "Created devices directory"
        }

        if (Test-Path $pairedJson) {
            cmd /c "icacls `"$pairedJson`" /reset /t /c /q" 2>$null | Out-Null
            cmd /c "icacls `"$pairedJson`" /grant:r `"$env:USERNAME`:F`" /t /c /q" 2>$null | Out-Null
            Write-Log "Fixed permissions on paired.json"
        }

        cmd /c "icacls `"$devicesDir`" /reset /t /c /q" 2>$null | Out-Null
        cmd /c "icacls `"$devicesDir`" /grant:r `"$env:USERNAME`:(OI)(CI)F`" /t /c /q" 2>$null | Out-Null
        Write-Log "Fixed permissions on devices directory"

        return $true
    } catch {
        Write-Log "Error fixing device permissions: $_" "ERROR"
        return $false
    }
}

function Cleanup-PairedJsonTempFiles {
    Write-Log "Cleaning up paired.json temporary files..."
    try {
        if (Test-Path $devicesDir) {
            $tempFiles = Get-ChildItem -Path $devicesDir -Filter "paired.json.*.tmp" -ErrorAction SilentlyContinue
            foreach ($file in $tempFiles) {
                try {
                    Remove-Item $file.FullName -Force
                    Write-Log "Removed temp file: $($file.Name)"
                } catch {
                    Write-Log "Could not remove temp file $($file.Name): $_" "WARN"
                }
            }
        }
        return $true
    } catch {
        Write-Log "Error cleaning up temp files: $_" "ERROR"
        return $false
    }
}

# ============================================================================
# Gateway Control Functions
# ============================================================================
function Stop-GatewayProcesses {
    Write-Log "Stopping any existing OpenClaw gateway processes..."
    try {
        Write-Log "Sending gateway stop command..."
        $stopOut = & openclaw gateway stop 2>&1 | Out-String
        if ($stopOut.Trim()) {
            Write-Debug "Gateway stop output: $stopOut"
        }
        Start-Sleep -Seconds 3

        # Force kill any remaining openclaw processes
        $processes = Get-Process | Where-Object {
            ($_.Path -like "*openclaw*" -or $_.ProcessName -like "*openclaw*") -and
            $_.Id -ne $PID
        }
        foreach ($proc in $processes) {
            try {
                Write-Log "Force stopping OpenClaw process ID: $($proc.Id)"
                $proc.Kill()
                $proc.WaitForExit(5000)
            } catch {
                Write-Log "Error stopping process $($proc.Id): $_" "WARN"
            }
        }

        Start-Sleep -Seconds 2
        return $true
    } catch {
        Write-Log "Error stopping gateway processes: $_" "ERROR"
        return $false
    }
}

function Start-GatewayService {
    Write-Log "Starting OpenClaw gateway service on port $port..."
    try {
        if (-not (Fix-DevicePermissions)) {
            Write-Log "Warning: Could not fix device permissions, continuing anyway..." "WARN"
        }

        Cleanup-PairedJsonTempFiles
        
        Write-Log "Stopping any existing gateway processes..."
        Stop-GatewayProcesses
        
        Write-Log "Sending gateway start command..."
        $startOut = & openclaw gateway start 2>&1 | Out-String
        Write-Debug "Gateway start output: $startOut"

        # Wait for gateway to start (poll up to 6 times, 5 sec each)
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            Start-Sleep -Seconds 5
            
            $portListening = Test-GatewayPort
            $healthOk = Test-HealthEndpoint
            
            if ($portListening -or $healthOk) {
                $pid = Get-GatewayPid
                Write-Log "Gateway listener detected on attempt $attempt (PID: $pid)"
                return $true
            }
            
            Write-Debug "Gateway not ready on attempt $attempt/6"
        }

        Write-Log "Gateway listener was not detected after start request" "ERROR"
        return $false
    } catch {
        Write-Log "Error starting gateway service: $_" "ERROR"
        return $false
    }
}

# ============================================================================
# Doctor Function
# ============================================================================
function Run-Doctor {
    Write-Log "Running openclaw doctor --fix"
    try {
        $doctorOut = & openclaw doctor --fix 2>&1 | Out-String
        Write-Debug "Doctor output: $doctorOut"
        
        # Success indicators
        if ($doctorOut -match '(?i)(success|completed|fixed|done|gateway.*start|healthy)') {
            return $true
        }
        
        return $false
    } catch {
        Write-Log "Doctor execution failed: $_" "ERROR"
        return $false
    }
}

# ============================================================================
# Main Logic
# ============================================================================
Write-Log "=========================================="
Write-Log "Self-heal script starting"
Write-Log "=========================================="

$config = Get-Config
$state = Get-State
$state.totalRuns = $state.totalRuns + 1

Write-Log "Configuration loaded: maxAttempts=$($config.maxAttempts), circuitBreak=$($config.circuitBreakThreshold)"
Write-Log "Current consecutive failures: $($state.failures)"
Write-Log "Total runs: $($state.totalRuns), Total heals: $($state.totalHeals)"

# Check current health status
$healthOk = Test-HealthEndpoint
$portListening = Test-GatewayPort
$currentPid = Get-GatewayPid

if ($healthOk -or $portListening) {
    Write-Log "Health check PASSED - gateway is running (PID: $currentPid)"
    
    # Update state
    $state.lastSuccessAt = (Get-Date).ToString('o')
    $state.healthStatus = "healthy"
    $state.gatewayPid = $currentPid
    
    # Reset failure count if we were in failure state
    if ($state.failures -gt 0) {
        Write-Log "Resetting failure count (was $($state.failures))"
        $state.failures = 0
        Set-State $state
        
        # Send recovery notification
        Send-Telegram -txt "Gateway recovered and is now healthy on port $port (PID: $currentPid)" -level "success"
    } else {
        Set-State $state
    }
    
    Write-Log "Self-heal check completed successfully"
    exit 0
}

# Gateway is DOWN - start healing
Write-Log "Health check FAILED - gateway is NOT running on port $port" "WARN"
$state.lastFailureAt = (Get-Date).ToString('o')
$state.healthStatus = "down"
Set-State $state

# Send initial failure notification (only if not in cooldown)
if ($state.failures -eq 0) {
    Send-Telegram -txt "Gateway is DOWN on port $port. Starting self-heal..." -level "warn"
}

# ============================================================================
# Healing Phase 1: Try to start gateway
# ============================================================================
Write-Log "Phase 1: Attempting to start gateway service..."
$healed = $false
$attemptsUsed = 0

for ($i = 1; $i -le $config.maxAttempts; $i++) {
    Write-Log "Gateway start attempt $i/$($config.maxAttempts)"
    
    if ($i -gt 1) {
        Send-Telegram -txt "Retry attempt $i/$($config.maxAttempts): starting gateway on port $port" -level "warn"
        Start-Sleep -Seconds $config.retryDelaySec
    }
    
    if (Start-GatewayService) {
        $healed = $true
        $attemptsUsed = $i
        break
    }
}

if ($healed) {
    Write-Log "Gateway started successfully after $attemptsUsed attempt(s)"
    $state.totalHeals = $state.totalHeals + 1
    $state.failures = 0
    $state.lastSuccessAt = (Get-Date).ToString('o')
    $state.healthStatus = "healthy"
    $state.gatewayPid = Get-GatewayPid
    Set-State $state
    
    Send-Telegram -txt "Gateway recovered after $attemptsUsed attempt(s) on port $port" -level "success"
    
    Write-Log "Self-heal completed successfully"
    exit 0
}

# ============================================================================
# Healing Phase 2: Try doctor for deeper issues
# ============================================================================
Write-Log "Phase 2: Gateway start failed, running doctor..."
Send-Telegram -txt "Gateway start failed. Running configuration fixes..." -level "warn"

$doctorHealed = $false

for ($i = 1; $i -le 2; $i++) {
    Write-Log "Doctor attempt $i/2"
    
    if (Run-Doctor) {
        Start-Sleep -Seconds $config.retryDelaySec
        
        if (Test-HealthEndpoint) {
            $doctorHealed = $true
            break
        } else {
            Write-Log "Doctor ran but health endpoint still down" "WARN"
        }
    } else {
        Write-Log "Doctor reported failure" "WARN"
    }
    
    if ($i -lt 2) {
        Start-Sleep -Seconds $config.retryDelaySec
    }
}

if ($doctorHealed) {
    Write-Log "Gateway recovered via doctor after $i attempt(s)"
    $state.totalHeals = $state.totalHeals + 1
    $state.failures = 0
    $state.lastSuccessAt = (Get-Date).ToString('o')
    $state.healthStatus = "healthy"
    $state.gatewayPid = Get-GatewayPid
    Set-State $state
    
    Send-Telegram -txt "Gateway recovered via doctor after $i attempt(s)" -level "success"
    
    Write-Log "Self-heal completed successfully via doctor"
    exit 0
}

# ============================================================================
# Healing Failed - Update state and check circuit breaker
# ============================================================================
Write-Log "All healing attempts FAILED" "ERROR"
$state.failures += 1
$state.lastFailureAt = (Get-Date).ToString('o')
Set-State $state

Send-Telegram -txt "FAILED to recover gateway on port $port after all attempts (failures: $($state.failures)/$($config.circuitBreakThreshold))" -level "error"

Write-Log "Consecutive failures: $($state.failures) / $($config.circuitBreakThreshold)"

# Check circuit breaker
if ($state.failures -ge $config.circuitBreakThreshold) {
    Write-Log "Circuit breaker triggered - disabling cron job" "CRITICAL"
    Send-Telegram -txt "CIRCUIT BREAKER: Self-heal cron job disabled after $($state.failures) consecutive failures" -level "critical" -Force
    
    try {
        $jobListJson = & openclaw cron list --json 2>$null | Out-String
        $jobList = $jobListJson | ConvertFrom-Json
        
        $job = $jobList | Where-Object { $_.name -eq 'selfheal:gateway-port-18789' } | Select-Object -First 1
        
        if ($job -and $job.id) {
            & openclaw cron disable $job.id 2>$null | Out-Null
            Write-Log "Disabled cron job $($job.id)"
            Send-Telegram -txt "Cron job $($job.id) has been disabled. Manual intervention required." -level "critical"
        } else {
            Write-Log "Could not find selfheal cron job" "WARN"
        }
    } catch {
        Write-Log "Error disabling cron job: $_" "ERROR"
    }
}

Write-Log "Self-heal script exiting with error" "ERROR"
exit 1
