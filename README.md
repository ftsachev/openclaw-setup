# OpenClaw: Hardened Software Dev Team Setup

A step-by-step setup prompt you can paste into **Claude Code** (or any coding agent) to install, configure, and harden [OpenClaw](https://openclaw.ai) on macOS, Linux, or Windows via WSL2 for a software development team.

OpenClaw turns Claude into a 24/7 personal AI assistant - persistent memory, tool access, and a direct line to your messaging apps (WhatsApp, Telegram, Slack, Discord, iMessage).

## Quick Start

Open a fresh **Claude Code** terminal and paste this:

```
Read https://raw.githubusercontent.com/amanaiproduct/openclaw/main/PROMPT.md and follow every step. Ask me which model provider I want to use when you need it.
```

That's it. The agent will walk you through installation, provider auth, security hardening, first-run setup, and a software-dev-team multi-agent bootstrap.

## Prerequisites

- **macOS, Linux, or Windows 11 with WSL2**
- **Node.js 22+** and **npm**
- **One model provider credential** for Anthropic, Codex, Gemini, OpenRouter, or another OpenClaw-supported provider
- A phone with **WhatsApp** (or a Telegram bot token, or Slack app credentials)

### Provider Notes

This repo no longer assumes Anthropic-only bootstrap.

Common good paths:
- **Codex**: OpenAI Codex OAuth
- **Gemini**: Gemini CLI OAuth
- **Anthropic**: API key or setup-token
- **OpenRouter**: API key, including routes to models like Nemotron 120B when supported by OpenRouter

### Windows Notes

Windows support in this repo is built around **WSL2 Ubuntu** for the OpenClaw runtime, with optional **Windows Task Scheduler** to keep a watchdog running after sign-in. The gateway still binds to `127.0.0.1` inside WSL, which keeps the security model aligned with the macOS/Linux flow.

## What Happens

1. The agent reads the setup prompt and installs OpenClaw
2. It asks which model provider to use and configures auth for that provider
3. It configures the gateway, API auth, and starts the service
4. It connects your messaging channel (WhatsApp QR code, Telegram bot, etc.)
5. You send your first message to start the identity/personality setup
6. It hardens security: loopback binding, token auth, permissions, watchdog
7. It bootstraps a software-dev-team specialist group with routing, handoff rules, and per-agent model assignments

## What It Does

### Phase 1: Install & Connect
- Installs OpenClaw via npm
- Selects a supported model provider and authenticates it
- Runs the onboarding wizard in a coding-agent-safe mode or equivalent provider auth flow
- Installs the gateway with the native service manager when available, or falls back to a background process

### Phase 2: Harden & Verify
- Locks down file permissions (`chmod 700` on config directory in Unix-like environments, WSL included)
- Enforces loopback-only gateway binding
- Sets up token authentication
- Configures group chat safety (allowlist + require-mention)
- Installs a watchdog service for automatic crash recovery
- Runs a full security audit
- Verifies everything works end-to-end

### Phase 3: Software Dev Team Bootstrap
- Defines a default seven-agent software team: `claudia`, `assistant`, `backend`, `frontend`, `devops`, `devsecops`, `qa-review`
- Allows each agent to use a different LLM or provider when the task warrants it
- Adds routing rules so requests go to the right specialist instead of one generalist improvising everything
- Adds handoff contracts, approval boundaries, verification gates, and a lightweight management interface for role-to-model assignments
- Documents optional add-on specialists like `marketing`, `product-design`, `data-analyst`, and `research`

## What's Inside

```
├── README.md       <- You're here
├── PROMPT.md       <- The setup prompt (paste into Claude Code)
└── config/
    ├── ai.openclaw.gateway.plist    <- LaunchAgent template
    ├── ai.openclaw.watchdog.plist   <- Watchdog LaunchAgent
    ├── watchdog.sh                  <- Unix/WSL health check script
    ├── watchdog.ps1                 <- Windows Task Scheduler wrapper
    └── openclaw-watchdog.xml        <- Scheduled Task template for Windows
```

## Security Model

This setup is opinionated about security:

- **Gateway binds to localhost only** - not exposed to your network
- **Token auth required** - no unauthenticated access
- **Group chats require @mention** - bot won't speak unprompted in groups
- **Config files are owner-only** - `chmod 700` on `~/.openclaw` in macOS/Linux/WSL
- **Watchdog monitors health** - auto-restarts if gateway becomes unresponsive
- **Prompt injection awareness** - workspace files train the agent to reject embedded commands

If you use Tailscale, the gateway can be exposed to your tailnet (but never to the public internet via Funnel).

## After Setup

Your agents wake up fresh each session but persist through files:

| File | What It Is |
|------|-----------|
| `SOUL.md` | Personality, values, boundaries |
| `AGENTS.md` | Operating manual (memory rules, security, workflow) |
| `MEMORY.md` | Long-term memory (curated by the agent) |
| `memory/*.md` | Daily notes |
| `IDENTITY.md` | Agent's name, vibe, emoji |
| `USER.md` | Your info (name, timezone, preferences) |
| `AGENT_MODELS.md` | Per-role provider/model assignments |

These are created by OpenClaw's onboarding. The hardening prompt adds security rules and operational patterns on top.

## Default Team

The default specialist set is optimized for software delivery:

- `claudia` - main contact and orchestrator; clarifies scope, routes work, merges outputs, and owns the final answer
- `assistant` - intake, note capture, recurring follow-ups, task grooming, and coordination support
- `backend` - APIs, integrations, data flow, background jobs, and service logic
- `frontend` - UI, accessibility, responsive behavior, and design implementation
- `devops` - deploys, CI/CD, logs, incidents, health checks, and rollbacks
- `devsecops` - auth, secrets, permissions, scanning, and security review
- `qa-review` - test planning, regression review, acceptance checks, and release readiness

## Agent Model Assignment

Each default specialist can be assigned a different LLM if needed.

Recommended pattern:
- `claudia` - balanced orchestrator model
- `assistant` - fast, cost-efficient coordination model with good summarization
- `backend` - strong coding and systems model
- `frontend` - strong coding model with UI/design sensitivity
- `devops` - strong tool-using operational model
- `devsecops` - strongest review/reasoning model available
- `qa-review` - detail-oriented review/test model

The setup also creates a simple management surface in the workspace so users can review and update role assignments without rewriting `AGENTS.md` from scratch.

## Optional Role Packs

These are documented as optional add-ons rather than defaults:

- `marketing` - launch copy, release notes, product messaging, docs polish
- `product-design` - design systems, UX flows, and design reviews
- `data-analyst` - metrics, dashboards, and experiment analysis
- `research` - discovery, competitive scans, and broad external research

## Platform Support

- **macOS**: full flow, including launchd templates in `config/`
- **Linux**: full flow, including systemd timer instructions
- **Windows**: supported through **WSL2** for the OpenClaw runtime, plus optional native Task Scheduler to invoke the WSL watchdog script

## Based On

A real setup running 24/7 on a headless Mac Mini with WhatsApp + iMessage, built over weeks of iteration. See the [blog post](https://amanalikhan.substack.com) for the full story.

## Links

- [OpenClaw](https://openclaw.ai) - [Docs](https://docs.openclaw.ai) - [Discord](https://discord.com/invite/clawd) - [GitHub](https://github.com/openclaw/openclaw)

---

Built by [Aman Khan](https://amanalikhan.com)
