# OpenClaw Rate Limit Fix - Add More Free Fallback Models
# This script adds multiple free model fallbacks to handle rate limits

$configPath = "$env:USERPROFILE\.openclaw\openclaw.json"

# Read config
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Add multiple free model fallbacks
# These are all free models available on OpenRouter
$freeModels = @(
    "openrouter/free",
    "openrouter/nvidia/nemotron-3-super-120b-a12b:free",
    "openrouter/meta-llama/llama-3-8b-instruct:free",
    "openrouter/google/gemma-7b-it:free",
    "openrouter/microsoft/phi-3-mini-128k-instruct:free"
)

# Update models config
$config.agents.defaults.models = @{}
foreach ($model in $freeModels) {
    $config.agents.defaults.models[$model] = @{}
}

# Update fallbacks list (keep all free models)
$config.agents.defaults.model.fallbacks = $freeModels

# Save backup
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item $configPath "$configPath.bak.$timestamp"

# Write updated config
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath

Write-Host "Updated OpenClaw fallback models:"
foreach ($model in $freeModels) {
    Write-Host "  - $model"
}
Write-Host ""
Write-Host "Note: Due to OpenClaw bug #28925, 429 errors don't auto-trigger fallback."
Write-Host "Workaround: Restart gateway or manually switch model when rate limited."
Write-Host ""
Write-Host "Backup saved to: $configPath.bak.$timestamp"
