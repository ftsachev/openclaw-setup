param(
    [string]$Distro = "Ubuntu",
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

$linuxCommand = if ($LinuxUser) {
    "sudo -u $LinuxUser bash -lc '$WatchdogScript'"
} else {
    "bash -lc '$WatchdogScript'"
}

Write-Log "Starting watchdog via WSL distro '$Distro'"
& wsl.exe -d $Distro -- bash -lc $linuxCommand
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Log "Watchdog exited with code $exitCode"
    exit $exitCode
}

Write-Log "Watchdog completed successfully"
