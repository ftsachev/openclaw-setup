# Self-heal script for OpenClaw gateway on port 18789
# Version: 3.0 (Adaptive healing with root cause analysis and predictive detection)
#
# Smart Features:
# - Adaptive healing that learns from past failures
# - Root cause analysis (OOM, crash, network, disk, Node.js)
# - Predictive degradation detection (response time trends)
# - Health metrics tracking with history
# - Escalation logic based on failure type
# - Dependency checks before healing attempts
# - Exponential backoff with smart retry delays
# - Comprehensive logging with structured JSON
# - Circuit-breaker with auto-recovery
# - Smart Telegram notifications with escalation

param(
    [switch]$Verbose = $false,
    [switch]$NoNotify = $false,
    [switch]$ForceRun = $false
)

# ============================================================================
# Configuration
# ============================================================================
$port = 18789
$healthUrl = "http://localhost:${port}/health"
$baseDir = "C:\Users\filip\.openclaw"
$logFile = Join-Path $baseDir "workspace\selfheal.log"
$metricsFile = Join-Path $baseDir "workspace\selfheal_metrics.json"
$stateFile = Join-Path $baseDir "workspace\selfheal_state.json"
$configFile = Join-Path $baseDir "workspace\selfheal_config.json"
$historyFile = Join-Path $baseDir "workspace\selfheal_history.json"
$devicesDir = Join-Path $baseDir "devices"
$pairedJson = Join-Path $devicesDir "paired.json"

# Defaults (can be overridden by config file)
$defaultConfig = @{
    maxAttempts = 3
    initialRetryDelaySec = 30
    maxRetryDelaySec = 300
    circuitBreakThreshold = 5
    autoRecoverCircuitBreakHours = 4
    notificationCooldownMin = 15
    botToken = "8629930214:AAEtuRiIAc665EXfslOY0538gmPQwGdPM68"
    chatId = "8537945694"
    # Predictive thresholds
    healthResponseTimeWarnMs = 1000
    healthResponseTimeCritMs = 5000
    # Dependency checks
    minFreeDiskMB = 100
    checkNodeHealth = $true
    # Escalation
    escalateAfterFailures = 3
    escalationChatId = ""  # Optional: different chat for critical alerts
}

# ============================================================================
# Logging Functions
# ============================================================================
function Write-Log {
    param(
        [string]$msg,
        [string]$level = "INFO",
        [hashtable]$data = $null
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
    $logLine = "[$ts] [$level] $msg"
    
    # Structured JSON log for metrics
    if ($data) {
        $jsonLog = @{
            timestamp = $ts
            level = $level
            message = $msg
            data = $data
        } | ConvertTo-Json -Compress
    }
    
    # Write to file
    try {
        if ($data) {
            $jsonLog | Out-File -FilePath $logFile -Append -Encoding utf8
        } else {
            $logLine | Out-File -FilePath $logFile -Append -Encoding utf8
        }
    } catch {
        # Silent fail on log write error
    }
    
    # Write to stdout for cron capture
    if ($Verbose -or $level -eq "ERROR" -or $level -eq "WARN" -or $level -eq "CRITICAL") {
        if ($data) {
            Write-Host "$logLine | $jsonLog"
        } else {
            Write-Host $logLine
        }
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
        try {
            $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content $configFile -Encoding utf8
            Write-Log "Created default config file"
        } catch {
            Write-Log "Could not create config file, using defaults" "WARN"
        }
        return $defaultConfig
    }
}

# ============================================================================
# State Management (Enhanced with learning)
# ============================================================================
function Get-DefaultState {
    return @{
        failures = 0
        consecutiveSuccesses = 0
        lastSuccessAt = $null
        lastFailureAt = $null
        lastNotificationAt = $null
        totalRuns = 0
        totalHeals = 0
        gatewayPid = $null
        healthStatus = "unknown"
        lastFailureReason = $null
        lastHealMethod = $null
        circuitBreakUntil = $null
        escalationLevel = 0
        adaptiveRetryDelaySec = 30
        failurePatterns = @{
            "oom" = 0
            "crash" = 0
            "network" = 0
            "disk" = 0
            "nodejs" = 0
            "unknown" = 0
        }
    }
}

function Get-State {
    if (Test-Path $stateFile) {
        try {
            $loadedState = Get-Content $stateFile -Raw | ConvertFrom-Json
            $defaultState = Get-DefaultState
            
            # Merge with defaults for any missing keys (v2->v3 migration)
            foreach ($key in $defaultState.Keys) {
                if (-not $loadedState.PSObject.Properties[$key]) {
                    $loadedState.$key = $defaultState[$key]
                }
            }
            
            # Ensure failurePatterns exists and has all keys
            if (-not $loadedState.failurePatterns) {
                $loadedState.failurePatterns = $defaultState.failurePatterns
            } else {
                foreach ($key in $defaultState.failurePatterns.Keys) {
                    if (-not $loadedState.failurePatterns.$key) {
                        $loadedState.failurePatterns.$key = 0
                    }
                }
            }
            
            return $loadedState
        } catch {
            Write-Log "Error reading state file, resetting" "WARN"
            return Get-DefaultState
        }
    } else {
        return Get-DefaultState
    }
}

function Set-State {
    param([object]$state)
    try {
        $state | ConvertTo-Json -Depth 10 | Set-Content $stateFile -Encoding utf8
        Write-Debug "State saved"
    } catch {
        Write-Log "Failed to save state: $_" "ERROR"
    }
}

# ============================================================================
# Metrics Tracking
# ============================================================================
function Get-Metrics {
    if (Test-Path $metricsFile) {
        try {
            return Get-Content $metricsFile -Raw | ConvertFrom-Json
        } catch {
            return Get-DefaultMetrics
        }
    } else {
        return Get-DefaultMetrics
    }
}

function Get-DefaultMetrics {
    return @{
        history = @()
        avgResponseTimeMs = 0
        responseTimeTrend = "stable"
        lastCheckAt = $null
        degradationDetectedAt = $null
    }
}

function Add-Metric {
    param(
        [double]$responseTimeMs,
        [string]$status,
        [int]$gatewayPid
    )
    
    $metrics = Get-Metrics
    $now = Get-Date
    
    $metric = @{
        timestamp = $now.ToString('o')
        responseTimeMs = [math]::Round($responseTimeMs, 2)
        status = $status
        gatewayPid = $gatewayPid
    }
    
    # Add to history (keep last 100)
    $metrics.history += $metric
    if ($metrics.history.Count -gt 100) {
        $metrics.history = $metrics.history | Select-Object -Last 100
    }
    
    # Calculate average (last 10)
    if ($metrics.history.Count -ge 10) {
        $recent = $metrics.history | Select-Object -Last 10
        $metrics.avgResponseTimeMs = [math]::Round(($recent | Measure-Object -Property responseTimeMs -Average).Average, 2)
        
        # Detect trend
        $first5 = $recent | Select-Object -First 5 | Measure-Object -Property responseTimeMs -Average
        $last5 = $recent | Select-Object -Last 5 | Measure-Object -Property responseTimeMs -Average
        
        if ($last5.Average -gt ($first5.Average * 1.5)) {
            $metrics.responseTimeTrend = "degrading"
            if (-not $metrics.degradationDetectedAt) {
                $metrics.degradationDetectedAt = $now.ToString('o')
            }
        } elseif ($last5.Average -lt ($first5.Average * 0.8)) {
            $metrics.responseTimeTrend = "improving"
            $metrics.degradationDetectedAt = $null
        } else {
            $metrics.responseTimeTrend = "stable"
            $metrics.degradationDetectedAt = $null
        }
    }
    
    $metrics.lastCheckAt = $now.ToString('o')
    
    try {
        $metrics | ConvertTo-Json -Depth 5 | Set-Content $metricsFile -Encoding utf8
    } catch {
        Write-Debug "Failed to save metrics: $_"
    }
}

# ============================================================================
# Failure History & Pattern Learning
# ============================================================================
function Add-FailureHistory {
    param(
        [string]$reason,
        [string]$method,
        [hashtable]$context
    )
    
    $history = @()
    if (Test-Path $historyFile) {
        try {
            $history = Get-Content $historyFile -Raw | ConvertFrom-Json
        } catch {}
    }
    
    $entry = @{
        timestamp = (Get-Date).ToString('o')
        reason = $reason
        method = $method
        context = $context
    }
    
    $history += $entry
    if ($history.Count -gt 50) {
        $history = $history | Select-Object -Last 50
    }
    
    try {
        $history | ConvertTo-Json -Depth 5 | Set-Content $historyFile -Encoding utf8
    } catch {}
}

function Analyze-FailurePattern {
    param([string]$currentReason)
    
    $state = Get-State
    $patterns = $state.failurePatterns
    
    if ($patterns.$currentReason) {
        $patterns.$currentReason++
    } else {
        $patterns.unknown++
    }
    
    # Find dominant failure pattern
    $dominant = ($patterns.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1).Name
    
    return @{
        patterns = $patterns
        dominant = $dominant
        recommendation = Get-HealRecommendation -pattern $dominant
    }
}

function Get-HealRecommendation {
    param([string]$pattern)
    
    switch ($pattern) {
        "oom" { 
            return "Consider increasing system memory or reducing gateway load. Check for memory leaks."
        }
        "crash" {
            return "Check gateway logs for panic/exception. Consider gateway rebuild or update."
        }
        "network" {
            return "Check network configuration, firewall rules, and port conflicts."
        }
        "disk" {
            return "Free up disk space. Check for log file bloat or database growth."
        }
        "nodejs" {
            return "Check Node.js version compatibility. Consider updating Node.js runtime."
        }
        default {
            return "No specific pattern detected. Manual investigation recommended."
        }
    }
}

# ============================================================================
# Telegram Notifications (Smart with escalation)
# ============================================================================
function Send-Telegram {
    param(
        [string]$txt,
        [string]$level = "info",
        [switch]$Force = $false,
        [hashtable]$data = $null
    )
    
    if ($NoNotify) {
        Write-Debug "Notifications disabled, skipping Telegram send"
        return $false
    }
    
    $config = Get-Config
    $state = Get-State
    
    # Escalation: use different chat for critical alerts
    $targetChatId = $config.chatId
    if ($level -eq "critical" -and $config.escalationChatId) {
        $targetChatId = $config.escalationChatId
        Write-Debug "Escalating to critical chat: $targetChatId"
    }
    
    # Check cooldown (unless forced or critical)
    if (-not $Force -and $level -ne "critical") {
        if ($state.lastNotificationAt) {
            try {
                $lastNotify = [DateTime]::Parse($state.lastNotificationAt)
                $cooldownMin = $config.notificationCooldownMin
                $elapsed = (Get-Date) - $lastNotify
                
                if ($elapsed.TotalMinutes -lt $cooldownMin) {
                    Write-Debug "Notification cooldown active ($([math]::Round($elapsed.TotalMinutes, 1)) min)"
                    return $false
                }
            } catch {
                Write-Debug "Could not parse lastNotificationAt, sending anyway"
            }
        }
    }
    
    # Format with emoji and level indicator
    $emoji = switch ($level) {
        "critical" { "🚨" }
        "error"    { "❌" }
        "warn"     { "⚠️" }
        "success"  { "✅" }
        "info"     { "ℹ️" }
        "degraded" { "📉" }
        default    { "🦞" }
    }
    
    $priority = switch ($level) {
        "critical" { "[CRITICAL]" }
        "error"    { "[ERROR]" }
        "warn"     { "[WARNING]" }
        default    { "" }
    }
    
    $formattedMsg = "$emoji OpenClaw Self-Heal $priority`n`n$txt"
    
    if ($data) {
        $formattedMsg += "`n`n``````json`n$($data | ConvertTo-Json -Depth 3)`n``````"
    }
    
    $formattedMsg += "`n`n_Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm')_"
    
    $uri = "https://api.telegram.org/bot$($config.botToken)/sendMessage"
    
    try {
        $body = @{
            chat_id = $targetChatId
            text = $formattedMsg
            parse_mode = "Markdown"
        }
        
        Invoke-RestMethod -Method Post -Uri $uri -Body $body -ErrorAction Stop | Out-Null
        Write-Debug "Telegram notification sent to $targetChatId"
        
        $state.lastNotificationAt = (Get-Date).ToString('o')
        Set-State $state
        
        return $true
    } catch {
        Write-Log "Telegram send failed: $_" "WARN"
        return $false
    }
}

# ============================================================================
# Dependency Checks
# ============================================================================
function Test-SystemDependencies {
    Write-Log "Checking system dependencies..."
    $issues = @()
    
    # Check disk space
    try {
        $disk = Get-PSDrive -Name (Split-Path $baseDir -Qualifier).TrimEnd(':') -ErrorAction SilentlyContinue
        if ($disk) {
            $freeMB = [math]::Round($disk.Free / 1MB, 2)
            $config = Get-Config
            
            if ($freeMB -lt $config.minFreeDiskMB) {
                $issues += "Low disk space: ${freeMB}MB free (min: $($config.minFreeDiskMB)MB)"
                Write-Log "DISK CHECK FAILED: ${freeMB}MB free" "WARN"
            } else {
                Write-Debug "Disk space OK: ${freeMB}MB free"
            }
        }
    } catch {
        Write-Debug "Could not check disk space: $_"
    }
    
    # Check Node.js health
    $config = Get-Config
    if ($config.checkNodeHealth) {
        try {
            $nodeVersion = & node --version 2>&1 | Out-String
            if ($nodeVersion -match 'v(\d+)\.') {
                $majorVersion = [int]$matches[1]
                if ($majorVersion -lt 18) {
                    $issues += "Node.js version outdated: $nodeVersion (recommended: 18+)"
                    Write-Log "NODE CHECK WARN: Version $nodeVersion" "WARN"
                } else {
                    Write-Debug "Node.js OK: $nodeVersion"
                }
            }
        } catch {
            $issues += "Node.js not found or not in PATH"
            Write-Log "NODE CHECK FAILED: Node.js not found" "WARN"
        }
    }
    
    # Check if port is already in use by another process
    try {
        $existingConn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($existingConn) {
            $proc = Get-Process -Id $existingConn.OwningProcess -ErrorAction SilentlyContinue
            if ($proc -and $proc.ProcessName -notlike "*node*") {
                $issues += "Port $port in use by $($proc.ProcessName) (PID: $($proc.Id))"
                Write-Log "PORT CHECK FAILED: Port conflict with $($proc.ProcessName)" "ERROR"
            }
        }
    } catch {
        Write-Debug "Could not check port conflicts: $_"
    }
    
    return @{
        ok = ($issues.Count -eq 0)
        issues = $issues
    }
}

# ============================================================================
# Health Check Functions (with metrics)
# ============================================================================
function Test-HealthEndpoint {
    param([ref]$responseTimeMs = $null)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $resp = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
        $stopwatch.Stop()
        
        if ($responseTimeMs) {
            $responseTimeMs.Value = $stopwatch.ElapsedMilliseconds
        }
        
        if ($resp.status -ieq "ok" -or $resp.Status -ieq "ok") { return $true }
        if ($resp.ok -eq $true) { return $true }
        if ($resp -is [string] -and $resp -match '(?i)ok') { return $true }
        return $false
    } catch {
        $stopwatch.Stop()
        if ($responseTimeMs) {
            $responseTimeMs.Value = $stopwatch.ElapsedMilliseconds
        }
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
    } catch {}
    return $null
}

function Get-ProcessMemory {
    param([int]$pid)
    try {
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            return @{
                privateMemoryMB = [math]::Round($proc.PrivateMemorySize64 / 1MB, 2)
                workingSetMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                cpuPercent = [math]::Round($proc.CPU, 2)
            }
        }
    } catch {}
    return $null
}

# ============================================================================
# Root Cause Analysis
# ============================================================================
function Analyze-FailureReason {
    Write-Log "Analyzing failure root cause..."
    
    $reasons = @()
    
    # Check for OOM indicators
    $currentPid = Get-GatewayPid
    if ($currentPid) {
        $mem = Get-ProcessMemory -pid $currentPid
        if ($mem -and $mem.workingSetMB -gt 500) {
            $reasons += @{
                type = "oom"
                confidence = "medium"
                detail = "Gateway using ${mem.workingSetMB}MB RAM"
            }
            Write-Log "POSSIBLE OOM: Gateway using ${mem.workingSetMB}MB" "WARN"
        }
    }
    
    # Check for recent crashes (check if process died unexpectedly)
    $state = Get-State
    if ($state.gatewayPid -and $state.gatewayPid -ne $currentPid) {
        $reasons += @{
            type = "crash"
            confidence = "high"
            detail = "Gateway PID changed from $($state.gatewayPid) to $currentPid"
        }
        Write-Log "POSSIBLE CRASH: PID changed from $($state.gatewayPid)" "WARN"
    }
    
    # Check for network issues
    try {
        $testConn = Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $testConn) {
            $reasons += @{
                type = "network"
                confidence = "high"
                detail = "Cannot connect to localhost:$port"
            }
        }
    } catch {
        $reasons += @{
            type = "network"
            confidence = "medium"
            detail = "Network test failed: $_"
        }
    }
    
    # Check disk space
    $diskCheck = Test-SystemDependencies
    if (-not $diskCheck.ok) {
        $diskIssues = $diskCheck.issues | Where-Object { $_ -match "disk" }
        if ($diskIssues) {
            $reasons += @{
                type = "disk"
                confidence = "high"
                detail = $diskIssues -join "; "
            }
        }
    }
    
    # Check Node.js
    if ($diskCheck.issues | Where-Object { $_ -match "Node" }) {
        $reasons += @{
            type = "nodejs"
            confidence = "medium"
            detail = "Node.js issue detected"
        }
    }
    
    # Return most likely cause
    if ($reasons.Count -gt 0) {
        $primary = $reasons | Where-Object { $_.confidence -eq "high" } | Select-Object -First 1
        if (-not $primary) {
            $primary = $reasons | Select-Object -First 1
        }
        return $primary
    }
    
    return @{
        type = "unknown"
        confidence = "low"
        detail = "No specific cause identified"
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
# Circuit Breaker Management
# ============================================================================
function Test-CircuitBreaker {
    $state = Get-State
    
    if ($state.circuitBreakUntil) {
        try {
            $breakUntil = [DateTime]::Parse($state.circuitBreakUntil)
            $now = Get-Date
            
            if ($now -lt $breakUntil) {
                $remaining = [math]::Round(($breakUntil - $now).TotalMinutes, 1)
                Write-Log "Circuit breaker active: ${remaining}m remaining" "WARN"
                return $true
            } else {
                Write-Log "Circuit breaker expired, re-enabling self-heal"
                $state.circuitBreakUntil = $null
                $state.failures = 0
                $state.escalationLevel = 0
                Set-State $state
                return $false
            }
        } catch {
            Write-Log "Error parsing circuit break timestamp, resetting" "WARN"
            $state.circuitBreakUntil = $null
            Set-State $state
            return $false
        }
    }
    
    return $false
}

function Trigger-CircuitBreaker {
    param([int]$failureCount)
    
    $config = Get-Config
    $state = Get-State
    
    $breakHours = $config.autoRecoverCircuitBreakHours
    $breakUntil = (Get-Date).AddHours($breakHours)
    
    $state.circuitBreakUntil = $breakUntil.ToString('o')
    $state.escalationLevel = [math]::Min($state.escalationLevel + 1, 3)
    Set-State $state
    
    Write-Log "Circuit breaker triggered until $breakUntil" "CRITICAL"
}

# ============================================================================
# Adaptive Retry Logic
# ============================================================================
function Get-AdaptiveRetryDelay {
    param([int]$attempt)
    
    $state = Get-State
    $config = Get-Config
    
    # Use adaptive delay from state if available, otherwise calculate
    $baseDelay = if ($state.adaptiveRetryDelaySec) { $state.adaptiveRetryDelaySec } else { $config.initialRetryDelaySec }
    
    # Exponential backoff with cap
    $delay = [math]::Min($baseDelay * [math]::Pow(2, $attempt - 1), $config.maxRetryDelaySec)

    Write-Debug "Retry delay for attempt $attempt : $($delay)s (base: $($baseDelay)s)"
    return [int]$delay
}

function Update-AdaptiveConfig {
    param(
        [bool]$success,
        [int]$attemptsUsed
    )
    
    $state = Get-State
    $config = Get-Config
    
    if ($success) {
        # If healed quickly, reduce retry delay
        if ($attemptsUsed -le 1 -and $state.adaptiveRetryDelaySec -gt $config.initialRetryDelaySec) {
            $state.adaptiveRetryDelaySec = [math]::Max($config.initialRetryDelaySec, $state.adaptiveRetryDelaySec * 0.8)
            Write-Log "Adaptive: Reduced retry delay to $($state.adaptiveRetryDelaySec)s"
        }
        $state.consecutiveSuccesses++
        
        # After many successes, reset to default
        if ($state.consecutiveSuccesses -ge 10) {
            $state.adaptiveRetryDelaySec = $config.initialRetryDelaySec
            $state.consecutiveSuccesses = 0
        }
    } else {
        # If failed, increase retry delay
        $state.adaptiveRetryDelaySec = [math]::Min($config.maxRetryDelaySec, $state.adaptiveRetryDelaySec * 1.2)
        $state.consecutiveSuccesses = 0
        Write-Log "Adaptive: Increased retry delay to $($state.adaptiveRetryDelaySec)s"
    }
    
    Set-State $state
}

# ============================================================================
# Predictive Degradation Detection
# ============================================================================
function Test-PredictiveDegradation {
    $config = Get-Config
    $metrics = Get-Metrics
    
    if ($metrics.avgResponseTimeMs -gt 0) {
        if ($metrics.avgResponseTimeMs -ge $config.healthResponseTimeCritMs) {
            Write-Log "CRITICAL DEGRADATION: Avg response ${metrics.avgResponseTimeMs}ms >= ${config.healthResponseTimeCritMs}ms" "CRITICAL"
            return "critical"
        } elseif ($metrics.avgResponseTimeMs -ge $config.healthResponseTimeWarnMs) {
            Write-Log "WARNING DEGRADATION: Avg response ${metrics.avgResponseTimeMs}ms >= ${config.healthResponseTimeWarnMs}ms" "WARN"
            return "warning"
        }
    }
    
    if ($metrics.responseTimeTrend -eq "degrading") {
        $degradedSince = $null
        if ($metrics.degradationDetectedAt) {
            try {
                $degradedSince = [DateTime]::Parse($metrics.degradationDetectedAt)
                $hours = [math]::Round((Get-Date - $degradedSince).TotalHours, 1)
                Write-Log "Degrading trend detected ${hours}h ago" "WARN"
                return "trend"
            } catch {}
        }
    }
    
    return $null
}

# ============================================================================
# Main Logic
# ============================================================================
Write-Log "==========================================" "INFO"
Write-Log "Self-heal script v3.0 starting" "INFO"
Write-Log "==========================================" "INFO"

$config = Get-Config
$state = Get-State
$state.totalRuns = $state.totalRuns + 1

Write-Log "Config: maxAttempts=$($config.maxAttempts), circuitBreak=$($config.circuitBreakThreshold)" "INFO"
Write-Log "State: failures=$($state.failures), heals=$($state.totalHeals), runs=$($state.totalRuns)" "INFO"

# Check circuit breaker
if (Test-CircuitBreaker) {
    Write-Log "Skipping heal - circuit breaker active" "WARN"
    exit 0
}

# Check for predictive degradation
$degradation = Test-PredictiveDegradation
if ($degradation -and -not $ForceRun) {
    $metrics = Get-Metrics
    $msg = "Predictive degradation detected`n"
    $msg += "Avg Response: ${metrics.avgResponseTimeMs}ms`n"
    $msg += "Trend: ${metrics.responseTimeTrend}`n"
    $msg += "Recommendation: Monitor closely, may need intervention"
    
    Send-Telegram -txt $msg -level "degraded" -data @{
        avgResponseTimeMs = $metrics.avgResponseTimeMs
        trend = $metrics.responseTimeTrend
    }
}

# Check system dependencies
$deps = Test-SystemDependencies
if (-not $deps.ok) {
    Write-Log "Dependency check failed: $($deps.issues -join ', ')" "ERROR"
    $state.lastFailureReason = "dependency"
    Set-State $state
    
    Send-Telegram -txt "System dependency issues detected:`n$($deps.issues -join "`n")" -level "error"
}

# Check current health status with metrics
$responseTime = 0
$healthOk = Test-HealthEndpoint ([ref]$responseTime)
$portListening = Test-GatewayPort
$currentPid = Get-GatewayPid

# Record metrics
Add-Metric -responseTimeMs $responseTime -status $(if ($healthOk) { "healthy" } else { "down" }) -gatewayPid $currentPid

if ($healthOk -or $portListening) {
    Write-Log "Health check PASSED - gateway running (PID: $currentPid, response: ${responseTime}ms)" "INFO"
    
    $state.lastSuccessAt = (Get-Date).ToString('o')
    $state.healthStatus = "healthy"
    $state.gatewayPid = $currentPid
    if ($state.consecutiveSuccesses) {
        $state.consecutiveSuccesses = $state.consecutiveSuccesses + 1
    } else {
        $state.consecutiveSuccesses = 1
    }
    
    if ($state.failures -gt 0) {
        Write-Log "Resetting failure count (was $($state.failures))"
        $state.failures = 0
        $state.escalationLevel = 0
        Set-State $state
        Send-Telegram -txt "Gateway recovered and healthy on port $port (PID: $currentPid, response: ${responseTime}ms)" -level "success"
    } else {
        Set-State $state
    }
    
    Write-Log "Self-heal check completed successfully" "INFO"
    exit 0
}

# Gateway is DOWN - start healing
Write-Log "Health check FAILED - gateway NOT running on port $port" "WARN"
$state.lastFailureAt = (Get-Date).ToString('o')
$state.healthStatus = "down"
Set-State $state

# Root cause analysis
$rootCause = Analyze-FailureReason
Write-Log "Root cause analysis: $($rootCause.type) (confidence: $($rootCause.confidence)) - $($rootCause.detail)" "WARN"
$state.lastFailureReason = $rootCause.type

# Analyze failure patterns
$patternAnalysis = Analyze-FailurePattern -currentReason $rootCause.type
$state.failurePatterns = $patternAnalysis.patterns

# Send initial notification
if ($state.failures -eq 0) {
    $msg = "Gateway is DOWN on port $port`n"
    $msg += "Root Cause: $($rootCause.type) ($($rootCause.confidence))`n"
    $msg += "Detail: $($rootCause.detail)`n"
    $msg += "Starting self-heal..."
    
    Send-Telegram -txt $msg -level "warn" -data @{
        rootCause = $rootCause.type
        confidence = $rootCause.confidence
        detail = $rootCause.detail
        recommendation = $patternAnalysis.recommendation
    }
}

# Add to failure history
Add-FailureHistory -reason $rootCause.type -method "initial" -context @{
    gatewayPid = $currentPid
    detail = $rootCause.detail
}

# ============================================================================
# Healing Phase 1: Try to start gateway
# ============================================================================
Write-Log "Phase 1: Attempting to start gateway service..." "INFO"
$healed = $false
$attemptsUsed = 0

for ($i = 1; $i -le $config.maxAttempts; $i++) {
    $delay = Get-AdaptiveRetryDelay -attempt $i
    Write-Log "Gateway start attempt $i/$($config.maxAttempts) (delay: ${delay}s)" "INFO"
    
    if ($i -gt 1) {
        Start-Sleep -Seconds $delay
        
        $escalationLevel = 0
        if ($state.escalationLevel) {
            $escalationLevel = $state.escalationLevel
        }
        if ($escalationLevel -ge 1) {
            Send-Telegram -txt "Retry attempt $i/$($config.maxAttempts) for gateway on port $port`nEscalation Level: $escalationLevel" -level "warn"
        }
    }
    
    if (Start-GatewayService) {
        $healed = $true
        $attemptsUsed = $i
        break
    }
}

if ($healed) {
    Write-Log "Gateway started successfully after $attemptsUsed attempt(s)" "INFO"
    $state.totalHeals = $state.totalHeals + 1
    $state.failures = 0
    $state.lastSuccessAt = (Get-Date).ToString('o')
    $state.healthStatus = "healthy"
    $state.gatewayPid = Get-GatewayPid
    $state.lastHealMethod = "start"
    
    Update-AdaptiveConfig -success $true -attemptsUsed $attemptsUsed
    Set-State $state
    
    $msg = "Gateway recovered after $attemptsUsed attempt(s) on port $port`n"
    $msg += "Method: gateway start`n"
    if ($patternAnalysis.recommendation) {
        $msg += "Tip: $($patternAnalysis.recommendation)"
    }
    
    Send-Telegram -txt $msg -level "success"
    
    Write-Log "Self-heal completed successfully" "INFO"
    exit 0
}

# ============================================================================
# Healing Phase 2: Try doctor for deeper issues
# ============================================================================
Write-Log "Phase 2: Gateway start failed, running doctor..." "WARN"
Send-Telegram -txt "Gateway start failed. Running configuration fixes..." -level "warn"

$doctorHealed = $false

for ($i = 1; $i -le 2; $i++) {
    Write-Log "Doctor attempt $i/2" "INFO"
    
    if (Run-Doctor) {
        Start-Sleep -Seconds $config.initialRetryDelaySec
        
        $responseTime = 0
        if (Test-HealthEndpoint ([ref]$responseTime)) {
            $doctorHealed = $true
            break
        } else {
            Write-Log "Doctor ran but health endpoint still down" "WARN"
        }
    } else {
        Write-Log "Doctor reported failure" "WARN"
    }
    
    if ($i -lt 2) {
        Start-Sleep -Seconds $config.initialRetryDelaySec
    }
}

if ($doctorHealed) {
    Write-Log "Gateway recovered via doctor" "INFO"
    $state.totalHeals = $state.totalHeals + 1
    $state.failures = 0
    $state.lastSuccessAt = (Get-Date).ToString('o')
    $state.healthStatus = "healthy"
    $state.gatewayPid = Get-GatewayPid
    $state.lastHealMethod = "doctor"
    
    Update-AdaptiveConfig -success $true -attemptsUsed 0
    Set-State $state
    
    Send-Telegram -txt "Gateway recovered via doctor configuration fixes" -level "success"
    
    Write-Log "Self-heal completed successfully via doctor" "INFO"
    exit 0
}

# ============================================================================
# Healing Failed - Update state and check circuit breaker
# ============================================================================
Write-Log "All healing attempts FAILED" "ERROR"
$state.failures += 1
$state.lastFailureAt = (Get-Date).ToString('o')

Update-AdaptiveConfig -success $false -attemptsUsed $config.maxAttempts
Set-State $state

# Escalation logic
$escalationLevel = 0
if ($state.escalationLevel) {
    $escalationLevel = $state.escalationLevel
}
$escalationMsg = ""
if ($state.failures -ge $config.escalateAfterFailures) {
    $escalationLevel = [math]::Min($escalationLevel + 1, 3)
    $state.escalationLevel = $escalationLevel
    Set-State $state
    
    $escalationMsg = "`n`nESCALATION LEVEL: $escalationLevel/3"
}

$msg = "FAILED to recover gateway on port $port`n"
$msg += "Failures: $($state.failures)/$($config.circuitBreakThreshold)$escalationMsg`n"
$msg += "Root Cause: $($rootCause.type)`n"
$msg += "Recommendation: $($patternAnalysis.recommendation)"

Send-Telegram -txt $msg -level "error" -data @{
    failures = $state.failures
    threshold = $config.circuitBreakThreshold
    rootCause = $rootCause.type
    recommendation = $patternAnalysis.recommendation
    escalationLevel = $escalationLevel
}

# Add to failure history
Add-FailureHistory -reason $rootCause.type -method "failed" -context @{
    attempts = $config.maxAttempts
    doctorAttempts = 2
    escalationLevel = $escalationLevel
}

# Check circuit breaker
if ($state.failures -ge $config.circuitBreakThreshold) {
    Trigger-CircuitBreaker -failureCount $state.failures
    
    Send-Telegram -txt "🚨 CIRCUIT BREAKER TRIGGERED`n`nSelf-heal disabled after $($state.failures) consecutive failures`n`nManual intervention required`n`nRecommendation: $($patternAnalysis.recommendation)" -level "critical" -Force
    
    try {
        $jobListJson = & openclaw cron list --json 2>$null | Out-String
        $jobList = $jobListJson | ConvertFrom-Json
        
        $job = $jobList | Where-Object { $_.name -eq 'selfheal:gateway-port-18789' } | Select-Object -First 1
        
        if ($job -and $job.id) {
            & openclaw cron disable $job.id 2>$null | Out-Null
            Write-Log "Disabled cron job $($job.id)" "CRITICAL"
            Send-Telegram -txt "Cron job $($job.id) has been disabled" -level "critical"
        }
    } catch {
        Write-Log "Error disabling cron job: $_" "ERROR"
    }
}

Write-Log "Self-heal script exiting with error" "ERROR"
exit 1

