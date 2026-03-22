# Fix denyCommands - Remove non-existent entries
$configPath = "$env:USERPROFILE\.openclaw\openclaw.json"

# Read config
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Update denyCommands to only valid entries
$config.gateway.nodes.denyCommands = @("camera.snap", "camera.clip", "screen.record")

# Save backup
Copy-Item $configPath "$configPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Write updated config
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath

Write-Host "Updated gateway.nodes.denyCommands to:"
Write-Host "  - camera.snap"
Write-Host "  - camera.clip"  
Write-Host "  - screen.record"
Write-Host ""
Write-Host "Removed (non-existent in OpenClaw):"
Write-Host "  - contacts.add"
Write-Host "  - calendar.add"
Write-Host "  - reminders.add"
Write-Host "  - sms.send"
Write-Host ""
Write-Host "Backup saved to: $configPath.bak.*"
