# OpenClaw: Hardened Software Dev Team Setup

A step-by-step setup prompt you can paste into **Claude Code** (or any coding agent) to install, configure, and harden [OpenClaw](https://openclaw.ai) on macOS, Linux, or Windows via WSL2 Fedora for a software development team.

OpenClaw turns Claude into a 24/7 personal AI assistant - persistent memory, tool access, and a direct line to your messaging apps (WhatsApp, Telegram, Slack, Discord, iMessage).

## Quick Start

Open a fresh **Claude Code** terminal and paste this:

```
Read https://raw.githubusercontent.com/ftsachev/openclaw-setup/main/PROMPT.md and follow every step. Ask me which model provider I want to use when you need it.
```

That's it. The agent will walk you through installation, provider auth, security hardening, first-run setup, and a software-dev-team multi-agent bootstrap.

## Prerequisites

- **macOS, Linux, or Windows 11 with WSL2 Fedora**
- **Node.js 22+**, **npm**, **git**, and **openssl** in the runtime distro
- **One model provider credential** for Anthropic, Codex, Gemini, OpenRouter, or another OpenClaw-supported provider
- A phone with **WhatsApp** or a **Discord** server if you want direct team chat access (Telegram and Slack are also supported)

### Provider Notes

This repo no longer assumes Anthropic-only bootstrap.

Common good paths:
- **Codex**: OpenAI Codex OAuth (interactive login flow)
- **Gemini**: Gemini CLI OAuth
- **Qwen**: Qwen Portal OAuth through the `qwen-portal-auth` plugin
- **Anthropic**: API key or setup-token
- **OpenRouter**: API key, including routes to models like Nemotron 120B when supported by OpenRouter

### Windows Notes

Windows support in this repo is built around **WSL2 Fedora** for the OpenClaw runtime, with optional **Windows Task Scheduler** to wrap the WSL watchdog after sign-in and refresh Windows-to-WSL localhost reachability when needed. Fedora distro names may vary in practice, such as `FedoraLinux` or `FedoraLinux-43`, so the helper script should auto-detect the installed Fedora distro by default. The gateway still binds to `127.0.0.1` inside WSL, which keeps the security model aligned with the macOS/Linux flow. If Windows cannot reach `http://127.0.0.1:18789/` while Fedora WSL can, the supported fallback is an elevated Windows `netsh interface portproxy` mapping to the current WSL IP.

## What Happens

1. The agent reads the setup prompt and installs OpenClaw
2. It asks which model provider to use and configures auth for that provider
3. It configures the gateway, API auth, and starts the service
4. It connects your messaging channel (WhatsApp, Discord, Telegram, Slack, etc.)
5. You send your first message to start the identity/personality setup
6. It hardens security: loopback binding, token auth, permissions, watchdog
7. It bootstraps a software-dev-team specialist group with routing, handoff rules, per-agent model assignments, repo knowledge files, Discord team access, and WhatsApp-safe team chat rules

Recent Windows/Fedora deployment lessons now built into the prompt:
- Qwen is handled as a first-class provider through `qwen-portal-auth`
- legacy configs that still say `models.providers.anthropic.api = "anthropic"` are corrected to `anthropic-messages`
- specialist agents are created in the runtime, not just described in workspace markdown
- new isolated agents are warmed once so they inherit the working auth profile from `main`

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
- Installs a watchdog service for automatic crash recovery and refreshes Windows `portproxy` mappings when WSL localhost forwarding is broken
- Runs a full security audit
- Verifies everything works end-to-end

### Phase 3: Software Dev Team Bootstrap
- Defines a default seven-agent software team: `claudia`, `assistant`, `backend`, `frontend`, `devops`, `devsecops`, `qa-review`
- Allows each agent to use a different LLM or provider when the task warrants it
- Adds routing rules so requests go to the right specialist instead of one generalist improvising everything
- Adds handoff contracts, approval boundaries, verification gates, and a lightweight management interface for role-to-model assignments
- Adds Discord and WhatsApp team-chat patterns so you can talk to the agents safely from your workspace channels
- Adds software-team operating rules for evidence-backed verification, resume/exit discipline, memory hygiene, safe git behavior, and repo knowledge refresh rules
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
- **Group chats require @mention** - bot won't speak unprompted in groups unless the workspace explicitly uses a role-aware team channel pattern
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
| `REPOS.md` | Registry of active repos, owners, docs, and refresh rules |
| `repo-notes/*.md` | Per-repo technical summaries and change notes |

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

## WhatsApp Team Chat

WhatsApp is the default personal/mobile contact surface.

Recommended pattern:
- direct chat with `claudia` by default
- optional direct chats or explicit routing for the other agents if the user wants them reachable individually
- one shared all-agents group for team visibility, but require explicit agent tagging there so not everyone replies to everything

Suggested tagging style in the shared group:
- `@claudia`
- `@assistant`
- `@backend`
- `@frontend`
- `@devops`
- `@devsecops`
- `@qa-review`

The workspace rules should treat the shared WhatsApp group as mention-required by default so a single message does not wake the whole team.

## Discord Team Chat

Discord is recommended when you want to talk to the team from one shared workspace.

Recommended pattern:
- one shared team channel for `claudia` and `assistant`
- optional specialist channels like `#backend`, `#frontend`, `#devops`, `#devsecops`, `#qa-review`
- route requests by channel or by explicit mention of the agent name
- keep `claudia` as the main escalation and coordination point

The setup prompt instructs the workspace rules to treat Discord as a role-aware team chat surface, not just a generic bot channel.

## Agent Model Assignment

Each default specialist can be assigned a different LLM if needed.

Recommended pattern:
- `claudia` - OpenAI Codex OAuth with medium reasoning
- `backend` - OpenAI Codex OAuth with low reasoning
- `frontend` - OpenAI Codex OAuth with low reasoning
- `assistant` - OpenRouter using `openrouter@nvidia/nemotron-3-super-120b-a12b:free`
- `devops` - OpenRouter using `openrouter@nvidia/nemotron-3-super-120b-a12b:free`
- `devsecops` - OpenRouter using `openrouter@nvidia/nemotron-3-super-120b-a12b:free`
- `qa-review` - OpenRouter using `openrouter@nvidia/nemotron-3-super-120b-a12b:free`

The setup also creates a simple management surface in the workspace so users can review and update role assignments without rewriting `AGENTS.md` from scratch. These defaults are prefilled for Codex OAuth and OpenRouter/Nemotron unless the user changes them during setup. In practice, the Codex OAuth step is interactive, so machine-side setup can be completed first and provider login finished afterward.

If you choose Qwen as the shared team provider, the updated bootstrap now uses `qwen-portal/coder-model` for the created specialist agents by default and validates that inherited auth works for each new agent.

## Optional Role Packs

These are documented as optional add-ons rather than defaults:

- `marketing` - launch copy, release notes, product messaging, docs polish
- `product-design` - design systems, UX flows, and design reviews
- `data-analyst` - metrics, dashboards, and experiment analysis
- `research` - discovery, competitive scans, and broad external research

## Repo Knowledge

The setup now teaches the workspace how to track your active repositories without relying on stale chat context.

It creates or updates:
- `REPOS.md` as the source of truth for active repositories, paths, purpose, primary docs, and owners
- `repo-notes/<repo>.md` files for concise repo-specific technical context
- refresh rules so the team revisits repo knowledge when a repository `README.md`, `technical-reference.md`, or equivalent core architecture doc changes

Recommended pattern:
- keep one entry per active repo
- link to the local path
- list the main runtime, stack, current purpose, important commands, and key risks
- refresh the repo note after meaningful documentation changes instead of relying on memory drift
## Workflow Rules

The setup prompt also teaches the workspace a few high-value operating defaults:

- verify non-trivial work with evidence, not just claims
- keep long-term memory curated instead of treating chat history as durable memory
- use a resume checklist after idle periods so the team checks memory, open tasks, and git state before continuing
- use a session-exit checklist so unfinished work, decisions, and follow-ups are not lost
- prefer high-level, clean commit messages with no AI attribution or noisy implementation detail
- avoid reading or exposing secrets from `.env`, secret folders, or private config files

These rules are intended to transfer the best parts of a strong day-to-day engineering agent workflow into the OpenClaw workspace.
## Windows Host Wrapper

If you want `openclaw` callable directly from Windows PowerShell, you can add a small wrapper in the Windows npm bin directory that forwards commands into your Fedora WSL runtime.

Recommended files:
- `%APPDATA%\npm\openclaw.cmd`
- `%APPDATA%\npm\openclaw.ps1`

Use your actual Fedora distro name in the wrapper, for example `FedoraLinux` or `FedoraLinux-43`.

This is optional convenience only. For runtime work, service debugging, and onboarding flows, running `openclaw` inside the Fedora WSL shell remains the more reliable path.
## Platform Support

- **macOS**: full flow, including launchd templates in `config/`
- **Linux**: full flow, including systemd timer instructions
- **Windows**: supported through **WSL2 Fedora** for the OpenClaw runtime, plus optional native Task Scheduler to invoke the WSL watchdog script

## Based On

A real setup running 24/7 on a headless Mac Mini with WhatsApp + iMessage, built over weeks of iteration. See the [blog post](https://amanalikhan.substack.com) for the full story.

## Links

- [OpenClaw](https://openclaw.ai) - [Docs](https://docs.openclaw.ai) - [Discord](https://discord.com/invite/clawd) - [This Fork](https://github.com/ftsachev/openclaw-setup)

---

Built by [Aman Khan](https://amanalikhan.com)


