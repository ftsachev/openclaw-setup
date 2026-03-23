#!/usr/bin/env pwsh
<#
.SYNOPSIS
    OpenClaw research wrapper for last30days skill
.DESCRIPTION
    Runs deep research on any topic from the last 30 days across
    Reddit, X, YouTube, Hacker News, Polymarket, and the web.
.PARAMETER Topic
    The topic to research (required)
.PARAMETER Quick
    Faster research with fewer sources (8-12 each)
.PARAMETER Deep
    Comprehensive research (50-70 Reddit, 40-60 X)
.PARAMETER Days
    Look back N days instead of 30 (default: 30)
.PARAMETER Emit
    Output format: compact, json, md, context (default: compact)
.EXAMPLE
    .\research.ps1 "AI video tools"
    .\research.ps1 "Nano Banana Pro" -Quick
    .\research.ps1 "prompt engineering" -Deep -Days 7
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Topic,
    
    [switch]$Quick,
    [switch]$Deep,
    
    [int]$Days = 30,
    
    [ValidateSet("compact", "json", "md", "context")]
    [string]$Emit = "compact",
    
    [string]$OutputFile = ""
)

# Find skill root
$PossiblePaths = @(
    "C:\Users\filip\.qwen\skills\last30days",
    "C:\Users\filip\.openclaw\workspace\last30days",
    "$env:USERPROFILE\.qwen\skills\last30days",
    "$env:USERPROFILE\.openclaw\workspace\last30days"
)

$SkillRoot = $null
foreach ($path in $PossiblePaths) {
    if (Test-Path (Join-Path $path "scripts\last30days.py")) {
        $SkillRoot = $path
        break
    }
}

if (-not $SkillRoot) {
    Write-Host "ERROR: Could not find last30days skill" -ForegroundColor Red
    Write-Host "Install from: https://github.com/mvanhorn/last30days-skill" -ForegroundColor Yellow
    exit 1
}

$ScriptPath = Join-Path $SkillRoot "scripts\last30days.py"

# Build arguments
$Args = @($Topic)
if ($Quick) { $Args += "--quick" }
if ($Deep) { $Args += "--deep" }
$Args += "--days=$Days"
$Args += "--emit=$Emit"

# Display header
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  last30days Research Engine" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Topic: $Topic" -ForegroundColor White
Write-Host "Sources: Reddit, X, YouTube, HN, Polymarket, Web" -ForegroundColor Gray
Write-Host "Lookback: $Days days" -ForegroundColor Gray
Write-Host "Mode: $(if ($Quick) { 'Quick' } elseif ($Deep) { 'Deep' } else { 'Default' })" -ForegroundColor Gray
Write-Host ""
Write-Host "Starting research... (this may take 2-8 minutes)" -ForegroundColor Yellow
Write-Host ""

# Run research
$StartTime = Get-Date
$Output = & python3 $ScriptPath @Args 2>&1
$EndTime = Get-Date
$Duration = New-TimeSpan -Start $StartTime -End $EndTime

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Research Complete" -ForegroundColor Green
Write-Host "  Duration: $($Duration.Minutes)m $($Duration.Seconds)s" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Save to file if specified
if ($OutputFile) {
    $Output | Out-File -FilePath $OutputFile -Encoding utf8 -NoNewline
    Write-Host "Research saved to: $OutputFile" -ForegroundColor Green
} else {
    # Output to stdout
    $Output | ForEach-Object { Write-Host $_ }
}
