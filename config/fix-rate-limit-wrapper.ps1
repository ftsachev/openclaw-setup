# OpenClaw Rate Limit Workaround - Manual Fallback Switch
# Use this when you hit 429 rate limit errors

param(
    [string]$Action = "status"
)

Write-Host "=== OpenClaw Rate Limit Workaround ==="
Write-Host ""

if ($Action -eq "status") {
    # Check current model and rate limit status
    Write-Host "Checking model status..."
    openclaw models status
    
} elseif ($Action -eq "switch") {
    # Switch to next available free model
    Write-Host "Switching to openrouter/free..."
    openclaw config set agents.defaults.model.primary "openrouter/free"
    Write-Host "Switched! Restart gateway to apply."
    Write-Host "Run: openclaw gateway restart"
    
} elseif ($Action -eq "restart") {
    # Restart gateway to clear rate limit cooldown
    Write-Host "Restarting OpenClaw gateway..."
    openclaw gateway restart
    Start-Sleep -Seconds 5
    Write-Host "Gateway restarted. Testing..."
    openclaw status
    
} elseif ($Action -eq "disable-fallback") {
    # Disable memory search to reduce API calls
    Write-Host "Disabling memory search (reduces API calls)..."
    openclaw config set agents.defaults.memorySearch.enabled false
    Write-Host "Done. This reduces embedding API calls."
}

Write-Host ""
Write-Host "Usage:"
Write-Host "  .\fix-rate-limit-wrapper.ps1 -Action status    # Check model status"
Write-Host "  .\fix-rate-limit-wrapper.ps1 -Action switch    # Switch to free model"
Write-Host "  .\fix-rate-limit-wrapper.ps1 -Action restart   # Restart gateway"
Write-Host "  .\fix-rate-limit-wrapper.ps1 -Action disable-fallback  # Disable memory search"
