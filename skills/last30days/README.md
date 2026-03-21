# last30days Skill for OpenClaw

Multi-mode research skill with persistent knowledge accumulation for OpenClaw.

## Features

- **One-shot Research** - Research topics from the last 30 days across Reddit, X, YouTube, Hacker News, and web
- **Watchlists** - Schedule recurring research on competitors, topics, or people
- **Briefings** - Get accumulated briefings from all watchlist research
- **History Query** - Search your accumulated research knowledge base

## Sources

| Source | What It Covers |
|--------|----------------|
| Reddit | Community discussions, AMAs, technical deep-dives |
| X (Twitter) | Real-time updates, expert commentary, threads |
| YouTube | Video essays, tutorials, conference talks |
| Hacker News | Tech community discussions, launch posts |
| Web | General search via Brave, Parallel AI, or OpenRouter |

## Installation

### Step 1: Clone or Copy

Copy this `last30days` folder to your skills directory:

```bash
# For Claude Code
cp -r skills/last30days ~/.claude/skills/last30days

# For OpenClaw
cp -r skills/last30days ~/.openclaw/skills/last30days

# For Codex
cp -r skills/last30days ~/.codex/skills/last30days
```

### Step 2: Install Python Dependencies

```bash
cd ~/.claude/skills/last30days  # or your target path
pip3 install -r requirements.txt  # if requirements.txt exists
```

The skill uses only Python stdlib + `requests` for HTTP calls.

### Step 3: Configure API Keys (Optional)

For web search enrichment, set one of these environment variables:

```bash
# Brave Search API
export BRAVE_API_KEY="your_key_here"

# Parallel AI Search API
export PARALLEL_API_KEY="your_key_here"

# OpenRouter API (for Sonar Pro / other models)
export OPENROUTER_API_KEY="your_key_here"
```

Add to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.) for persistence.

### Step 4: Verify Installation

```bash
# Test import
python3 ~/.claude/skills/last30days/scripts/last30days.py --help

# Run diagnostics
python3 ~/.claude/skills/last30days/scripts/last30days.py --diagnose
```

## Usage

### One-Shot Research

```
/last30days AI video tools
/last30days latest developments in quantum computing
```

### Watchlist Management

```
/last30days watch add "AI video tools" every week
/last30days watch list
/last30days watch remove "AI video tools"
```

### Briefings

```
/last30days briefing
/last30days briefing since 2026-03-01
```

### History Query

```
/last30days history "Runway ML"
/last30days history what did we learn about video generation
```

## Database

Research findings are stored in:

```
~/.local/share/last30days/research.db
```

SQLite with WAL mode for concurrent access.

## Output Modes

| Mode | Description |
|------|-------------|
| `compact` | Default - concise summary with key findings |
| `json` | Raw JSON output for programmatic use |
| `md` | Markdown formatted report |
| `context` | Context file for agent memory |
| `path` | File path to saved output |

## Options

```
--mock              Use fixtures instead of real API calls
--emit=MODE         Output mode: compact|json|md|context|path
--sources=MODE      Source selection: auto|reddit|x|both
--quick             Faster research (8-12 sources each)
--deep              Comprehensive research (50-70 Reddit, 40-60 X)
--debug             Enable verbose debug logging
--store             Persist findings to SQLite database
--diagnose          Show source availability diagnostics
```

## Example: Research + Store

```bash
python3 scripts/last30days.py "AI video tools" --store --deep
```

This will:
1. Research comprehensively across all sources
2. Store findings in SQLite database
3. Return a compact summary

## Files Structure

```
last30days/
├── SKILL.md                 # Main skill definition
├── README.md                # This file
├── scripts/
│   ├── last30days.py        # Main research engine
│   ├── store.py             # SQLite storage
│   ├── watchlist.py         # Watchlist CLI
│   ├── briefing.py          # Briefing generator
│   ├── ai_utils.py          # AI utilities
│   └── lib/
│       ├── bird_x.py        # X/Twitter search
│       ├── youtube_yt.py    # YouTube search
│       ├── reddit_enrich.py # Reddit API
│       ├── hackernews.py    # Hacker News search
│       ├── polymarket.py    # Polymarket prediction markets
│       ├── brave_search.py  # Brave Search API
│       ├── parallel_search.py  # Parallel AI search
│       ├── openrouter_search.py  # OpenRouter API
│       ├── websearch.py     # Generic web search
│       ├── render.py        # Output rendering
│       ├── ui.py            # UI utilities
│       └── ...              # Other utilities
└── variants/
    └── open/
        ├── SKILL.md         # Open variant definition
        ├── context.md       # Agent context/memory
        └── references/
            ├── research.md  # Research mode instructions
            ├── watchlist.md # Watchlist instructions
            ├── briefing.md  # Briefing instructions
            └── history.md   # History query instructions
```

## Troubleshooting

### Import Errors

```bash
# Ensure scripts/lib is in Python path
export PYTHONPATH="$HOME/.claude/skills/last30days/scripts:$PYTHONPATH"
```

### API Key Missing

If web search fails, check:

```bash
echo $BRAVE_API_KEY
echo $PARALLEL_API_KEY
echo $OPENROUTER_API_KEY
```

At least one should be set for web enrichment.

### Rate Limits

The skill has built-in rate limiting. If you hit API limits:
- Use `--quick` for faster, lighter research
- Wait a few minutes between runs
- Reduce `--deep` usage

## License

Same as parent OpenClaw project.

## Credits

Based on the `/last30days` skill by Aman Ali Khan, with OpenCLAW variant integration for watchlists, briefings, and web search.
