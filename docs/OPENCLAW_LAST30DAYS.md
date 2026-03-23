# OpenClaw + last30days Integration

## Overview

Integrate the `last30days` research skill with OpenClaw to enable deep research via Telegram chat.

## Installation

### Option 1: Use Qwen Code's Built-in Skill (Recommended)

The `last30days` skill is already installed at `~/.qwen/skills/last30days/`.

To use with OpenClaw, create a wrapper script that OpenClaw can call.

### Option 2: Install as OpenClaw Workspace Script

```powershell
# Copy skill to OpenClaw workspace
Copy-Item "~/.qwen/skills/last30days" -Recurse "C:\Users\filip\.openclaw\workspace\last30days"

# Create wrapper script for OpenClaw
```

## OpenClaw Wrapper Script

Create `C:\Users\filip\.openclaw\workspace\research.ps1`:

```powershell
#!/usr/bin/env pwsh
# OpenClaw research wrapper for last30days skill
# Usage: research.ps1 "<topic>" [--quick|--deep] [--days=N]

param(
    [string]$Topic,
    [switch]$Quick,
    [switch]$Deep,
    [int]$Days = 30,
    [string]$OutputFile = ""
)

$SkillRoot = "C:\Users\filip\.qwen\skills\last30days"
$ScriptPath = Join-Path $SkillRoot "scripts\last30days.py"

# Build arguments
$Args = @($Topic)
if ($Quick) { $Args += "--quick" }
if ($Deep) { $Args += "--deep" }
$Args += "--days=$Days"
$Args += "--emit=compact"

# Run research
Write-Host "Starting research on: $Topic"
Write-Host "This may take 2-8 minutes..."

$Output = & python3 $ScriptPath @Args 2>&1

# Save to file if specified
if ($OutputFile) {
    $Output | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Host "Research saved to: $OutputFile"
} else {
    # Output to stdout for OpenClaw
    $Output
}
```

## Configuration

### Required API Keys

Create `C:\Users\filip\.config\last30days\.env`:

```bash
# Required for Reddit, TikTok, Instagram
SCRAPECREATORS_API_KEY=your_key_here

# Optional but recommended for X/Twitter
XAI_API_KEY=xai-your_key_here
# OR use cookie auth (more reliable)
AUTH_TOKEN=your_twitter_auth_token
CT0=your_twitter_ct0

# Optional for web search
BRAVE_API_KEY=your_key_here
# OR
OPENROUTER_API_KEY=your_key_here

# Optional for Bluesky
BSKY_HANDLE=your.bsky.social
BSKY_APP_PASSWORD=your-app-password
```

### Set Permissions

```powershell
# Ensure .env is readable only by you
icacls "C:\Users\filip\.config\last30days\.env" /grant:r "$env:USERNAME:F" /inheritance:r
```

## Usage via Telegram

Send messages to your OpenClaw bot:

```
Research AI video tools from last 30 days
/last30days best project management tools
Research nano banana pro prompts for Gemini --quick
```

## OpenClaw Agent Integration

Add to `C:\Users\filip\.openclaw\workspace\AGENTS.md`:

```markdown
## Research Agent

When user asks about trends, news, or "what's happening" with a topic:

1. Use the last30days research skill
2. Run: `python C:\Users\filip\.qwen\skills\last30days\scripts\last30days.py "<topic>" --emit=compact`
3. Synthesize findings with citations
4. Present summary with stats block

**Example invocation:**
```bash
python C:\Users\filip\.qwen\skills\last30days\scripts\last30days.py "AI video tools" --days=30 --emit=compact
```

**Output format:**
- Key findings with citations (@handles, subreddits)
- Stats block showing sources and engagement
- Follow-up suggestions
```

## Quick Commands

```powershell
# Basic research
python C:\Users\filip\.qwen\skills\last30days\scripts\last30days.py "AI coding assistants"

# Quick research (faster, fewer sources)
python C:\Users\filip\.qwen\skills\last30days\scripts\last30days.py "Nano Banana Pro" --quick

# Deep research (comprehensive)
python C:\Users\filip\.qwen\skills\last30days\scripts\last30days.py "prompt engineering" --deep

# Last 7 days only
python C:\Users\filip\.qwen\skills\last30days\scripts\last30days.py "Kanye West" --days=7

# Save to file
python C:\Users\filip\.qwen\skills\last30days\scripts\last30days.py "Midjourney tips" --emit=md > research.md
```

## Troubleshooting

### Python Not Found

```powershell
# Check Python installation
python3 --version
# or
py --version
```

### API Key Errors

Check that `.env` file exists and has correct permissions:

```powershell
Test-Path "C:\Users\filip\.config\last30days\.env"
Get-Content "C:\Users\filip\.config\last30days\.env"
```

### SSL Certificate Errors (Python.org installation)

```powershell
# Run certificate installer
& "C:\Program Files\Python312\Install Certificates.command"
```

### X/Twitter Auth Issues

Verify auth tokens are valid:

```bash
node C:\Users\filip\.qwen\skills\last30days\scripts\lib\bird_x.py --whoami
```

## Sources Covered

| Source | API | Required Key |
|--------|-----|--------------|
| Reddit | ScrapeCreators | ✅ Yes |
| X/Twitter | xAI or GraphQL | Optional |
| YouTube | yt-dlp (local) | ❌ No |
| TikTok | ScrapeCreators | ✅ (same as Reddit) |
| Instagram | ScrapeCreators | ✅ (same as Reddit) |
| Hacker News | Algolia API | ❌ No |
| Polymarket | Gamma API | ❌ No |
| Bluesky | AT Protocol | Optional |
| Web | Brave/Parallel/OpenRouter | Optional |

## Output Example

```
✅ All agents reported back!
├─ 🟠 Reddit: 25 threads │ 3,420 upvotes │ 892 comments
├─ 🔵 X: 30 posts │ 12,500 likes │ 3,200 reposts
├─ 🔴 YouTube: 8 videos │ 450K views │ 5 with transcripts
├─ 🟡 HN: 12 stories │ 340 points │ 156 comments
├─ 📊 Polymarket: 3 markets │ "AI replaces devs by 2027: 12%"
├─ 🌐 Web: 15 pages — TechCrunch, Wired, The Verge
└─ 🗣️ Top voices: @sama (4.2K likes), @karpathy │ r/MachineLearning, r/ChatGPT
```

---

**Based on**: last30days-skill v2.9.5 by mvanhorn  
**License**: MIT  
**Source**: https://github.com/mvanhorn/last30days-skill
