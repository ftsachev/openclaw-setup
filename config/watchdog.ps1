param(
    [string]$Distro = "",
    [string]$LinuxUser = "",
    [string]$WatchdogScript = "~/.openclaw/watchdog.sh",
    [string]$LogPath = "$env:USERPROFILE\openclaw\watchdog.log",
    [switch]$NotifyOnFailure = $false
)

$logDir = Split-Path -Parent $LogPath
if ($logDir) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

# Telegram configuration (optional - for direct notifications)
$TelegramConfig = @{
    BotToken = ""  # Set your bot token or leave empty to use OpenClaw's config
    ChatId   = ""  # Set your chat ID or leave empty
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "[$timestamp] $Message"
}

function Send-TelegramNotification {
    param(
        [string]$Message,
        [string]$Level = "info"
    )
    
    if (-not $NotifyOnFailure) {
        return
    }
    
    # Try to get config from OpenClaw if botToken not set
    $botToken = $TelegramConfig.BotToken
    $chatId = $TelegramConfig.ChatId
    
    if (-not $botToken -or -not $chatId) {
        Write-Log "Telegram not configured for direct notifications"
        return
    }
    
    $emoji = switch ($Level) {
        "critical" { "🚨" }
        "error"    { "❌" }
        "warn"     { "⚠️" }
        "success"  { "✅" }
        default    { "ℹ️" }
    }
    
    $uri = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{
        chat_id = $chatId
        text = "$emoji OpenClaw Watchdog`n`n$Message`n`n_Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm')_"
        parse_mode = "Markdown"
    }
    
    try {
        Invoke-RestMethod -Method Post -Uri $uri -Body $body -ErrorAction Stop | Out-Null
        Write-Log "Telegram notification sent: $Level"
    } catch {
        Write-Log "Telegram send failed: $_"
    }
}

function Resolve-Distro {
    param([string]$Requested)
    if ($Requested) {
        return $Requested
    }

    $distros = & wsl.exe -l -q 2>$null
    $fedora = $distros | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^Fedora' } | Select-Object -First 1
    if ($fedora) {
        return $fedora
    }

    return 'FedoraLinux'
}

$ResolvedDistro = Resolve-Distro -Requested $Distro

function Get-WslIp {
    param([string]$TargetDistro)
    try {
        $ip = & wsl.exe -d $TargetDistro -- bash -lc "/usr/sbin/ip -4 addr show eth0 | /usr/bin/sed -n 's/.*inet \([0-9.]*\)\/.*/\1/p' | /usr/bin/head -n 1" 2>$null
        return ($ip | Select-Object -First 1).Trim()
    } catch {
        return ""
    }
}

function Test-WindowsGatewayReachability {
    try {
        $response = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:18789/ -TimeoutSec 5
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
    } catch {
        return $false
    }
}

function Ensure-PortProxy {
    param([string]$TargetDistro)
    $wslIp = Get-WslIp -TargetDistro $TargetDistro
    if (-not $wslIp) {
        Write-Log "Could not resolve WSL IP for distro '$TargetDistro'; skipping portproxy refresh"
        return
    }

    if (Test-WindowsGatewayReachability) {
        Write-Log "Windows can already reach OpenClaw on 127.0.0.1:18789; no portproxy refresh needed"
        return
    }

    Write-Log "Refreshing Windows portproxy rules for WSL IP $wslIp"
    & netsh interface portproxy delete v4tov4 listenaddress=127.0.0.1 listenport=18789 | Out-Null
    & netsh interface portproxy add v4tov4 listenaddress=127.0.0.1 listenport=18789 connectaddress=$wslIp connectport=18789 | Out-Null
    & netsh interface portproxy delete v4tov4 listenaddress=127.0.0.1 listenport=18791 | Out-Null
    & netsh interface portproxy add v4tov4 listenaddress=127.0.0.1 listenport=18791 connectaddress=$wslIp connectport=18791 | Out-Null
}

$linuxCommand = if ($LinuxUser) {
    "sudo -u $LinuxUser bash -lc '$WatchdogScript'"
} else {
    "bash -lc '$WatchdogScript'"
}

Write-Log "Starting watchdog via WSL distro '$ResolvedDistro' (Fedora auto-detect unless overridden)"
Ensure-PortProxy -TargetDistro $ResolvedDistro

& wsl.exe -d $ResolvedDistro -- bash -lc $linuxCommand
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Log "Watchdog exited with code $exitCode"
    Send-TelegramNotification -Message "Watchdog detected gateway issue (exit code: $exitCode). Check logs at $LogPath" -Level "error"
    exit $exitCode
}

Write-Log "Watchdog completed successfully"


