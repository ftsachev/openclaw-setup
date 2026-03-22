$ErrorActionPreference = "Continue"

$StartupFolder = [System.Environment]::GetFolderPath("Startup")

Write-Host "Uninstalling OpenClaw services..." -ForegroundColor Yellow

# --- Stop gateway ---
Write-Host "Stopping gateway..." -ForegroundColor Gray
& openclaw gateway stop 2>&1 | Out-Null

# --- Remove watchdog scheduled task ---
Write-Host "Stopping watchdog..." -ForegroundColor Gray
schtasks /end /tn "OpenClawWatchdog" 2>$null | Out-Null
Write-Host "Deleting watchdog task..." -ForegroundColor Gray
schtasks /delete /tn "OpenClawWatchdog" /f 2>$null | Out-Null

# --- Remove startup batch ---
$StartupBat = Join-Path $StartupFolder "OpenClawGateway.bat"
if (Test-Path $StartupBat) {
    Remove-Item $StartupBat -Force
    Write-Host "Removed startup item" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Services uninstalled." -ForegroundColor Green
