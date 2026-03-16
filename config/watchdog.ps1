param(
    [string]$Distro = "",
    [string]$LinuxUser = "",
    [string]$WatchdogScript = "~/.openclaw/watchdog.sh",
    [string]$LogPath = "$env:USERPROFILE\openclaw\watchdog.log"
)

$logDir = Split-Path -Parent $LogPath
if ($logDir) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "[$timestamp] $Message"
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

$linuxCommand = if ($LinuxUser) {
    "sudo -u $LinuxUser bash -lc '$WatchdogScript'"
} else {
    "bash -lc '$WatchdogScript'"
}

Write-Log "Starting watchdog via WSL distro '$ResolvedDistro' (Fedora auto-detect unless overridden)"
& wsl.exe -d $ResolvedDistro -- bash -lc $linuxCommand
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Log "Watchdog exited with code $exitCode"
    exit $exitCode
}

Write-Log "Watchdog completed successfully"

