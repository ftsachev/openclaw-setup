$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartupFolder = [System.Environment]::GetFolderPath("Startup")

Write-Host "Installing OpenClaw services..." -ForegroundColor Cyan

# --- Gateway: Startup batch file ---
$StartupBat = Join-Path $StartupFolder "OpenClawGateway.bat"
$batContent = @"
@echo off
start "" /min openclaw gateway
"@
Set-Content -Path $StartupBat -Value $batContent -Encoding ASCII
Write-Host "[OK] Startup item: $StartupBat" -ForegroundColor Green

# --- Watchdog: Scheduled task (every 2 min) ---
Write-Host "Registering OpenClawWatchdog task..." -ForegroundColor Yellow
$watchdogPath = Join-Path $ScriptDir "watchdog.ps1"
$watchdogPath = (Resolve-Path $watchdogPath).Path

schtasks /delete /tn "OpenClawWatchdog" /f 2>$null
$schResult = schtasks /create /tn "OpenClawWatchdog" /tr "powershell.exe -ExecutionPolicy Bypass -File `"$watchdogPath`"" /sc DAILY /st 00:00 /ri 2 /du 24:00 /f 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] OpenClawWatchdog scheduled task created" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Failed to create watchdog task: $schResult" -ForegroundColor Red
    Write-Host "  (Run as Administrator if ONSTART/ONLOGON triggers are needed)" -ForegroundColor Yellow
}

# --- Start services now ---
Write-Host ""
Write-Host "Starting services..." -ForegroundColor Cyan

# Start gateway via openclaw
$gwResult = & openclaw gateway start 2>&1
Write-Host "Gateway: $gwResult"

# Start watchdog
schtasks /run /tn "OpenClawWatchdog" 2>&1 | Out-Null
Write-Host "Watchdog: started"

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  Gateway: http://127.0.0.1:18789/" -ForegroundColor Gray
Write-Host "  Dashboard: openclaw status" -ForegroundColor Gray
