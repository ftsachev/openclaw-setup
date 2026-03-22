# Fix denyCommands - Clear list (no paired nodes)

$configPath = "$env:USERPROFILE\.openclaw\openclaw.json"

# Read config
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Clear denyCommands (no paired nodes in this setup)
$config.gateway.nodes.denyCommands = @()

# Save backup
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item $configPath "$configPath.bak.$timestamp"

# Write updated config
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath

Write-Host "Cleared gateway.nodes.denyCommands"
Write-Host ""
Write-Host "Rationale: No paired nodes in this Windows setup"
Write-Host "Gateway is bound to loopback only (127.0.0.1:18789)"
Write-Host ""
Write-Host "Backup saved to: $configPath.bak.$timestamp"
