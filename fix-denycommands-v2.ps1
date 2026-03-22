# Fix denyCommands - Use nodes.run instead
# Based on security audit suggestion: "Use exact command names like canvas.present, canvas.hide..."

$configPath = "$env:USERPROFILE\.openclaw\openclaw.json"

# Read config
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Update denyCommands to canvas commands (which are confirmed to exist)
# Remove camera/screen commands that the audit says are "unknown"
$config.gateway.nodes.denyCommands = @(
    "canvas.eval",
    "canvas.navigate", 
    "canvas.a2ui.push",
    "canvas.a2ui.pushJSONL",
    "canvas.a2ui.reset"
)

# Save backup
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item $configPath "$configPath.bak.$timestamp"

# Write updated config
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath

Write-Host "Updated gateway.nodes.denyCommands to canvas commands:"
Write-Host "  - canvas.eval"
Write-Host "  - canvas.navigate"
Write-Host "  - canvas.a2ui.push"
Write-Host "  - canvas.a2ui.pushJSONL"
Write-Host "  - canvas.a2ui.reset"
Write-Host ""
Write-Host "Removed (not recognized by gateway):"
Write-Host "  - camera.snap"
Write-Host "  - camera.clip"
Write-Host "  - screen.record"
Write-Host ""
Write-Host "Note: camera.* and screen.* are CLI commands, not gateway node invoke commands"
Write-Host ""
Write-Host "Backup saved to: $configPath.bak.$timestamp"
