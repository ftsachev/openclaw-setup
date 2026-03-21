# Agent Model Assignments

Use this file to decide which provider/model each specialist should use. These are defaults and can be changed any time.

| Agent | Primary Role | Preferred Provider | Preferred Model | Fallback | Notes |
|------|--------------|--------------------|-----------------|----------|-------|
| `claudia` | orchestration | Qwen Portal | qwen-portal/coder-model | OpenRouter `nvidia/nemotron-3-super-120b-a12b:free` | main contact; use medium reasoning |
| `assistant` | intake and support | Qwen Portal | qwen-portal/coder-model | OpenRouter `nvidia/nemotron-3-super-120b-a12b:free` | fast summaries, note capture, reminders |
| `backend` | APIs and services | Qwen Portal | qwen-portal/coder-model | OpenRouter `nvidia/nemotron-3-super-120b-a12b:free` | strong coding and systems reliability |
| `frontend` | UI and UX implementation | Qwen Portal | qwen-portal/coder-model | OpenRouter `nvidia/nemotron-3-super-120b-a12b:free` | strong coding plus design sensitivity |
| `devops` | deploys and operations | Qwen Portal | qwen-portal/coder-model | OpenRouter `nvidia/nemotron-3-super-120b-a12b:free` | tool use, logs, concise ops output |
| `devsecops` | security review | Qwen Portal | qwen-portal/coder-model | OpenRouter `nvidia/nemotron-3-super-120b-a12b:free` | strongest review and risk reasoning |
| `qa-review` | test and regression review | Qwen Portal | qwen-portal/coder-model | OpenRouter `nvidia/nemotron-3-super-120b-a12b:free` | detail, consistency, edge-case detection |

## Management Rules

- Each agent may use a different LLM if needed
- Cost-sensitive roles can use cheaper models when quality is still acceptable
- High-risk roles like `devsecops` and final `qa-review` should prefer the strongest reliable model available
- `claudia` is responsible for consulting this file before delegating work when model choice matters
- If a provider or model changes, update this file first, then any matching references in `AGENTS.md`
- Qwen is the primary provider for all agents (qwen-portal/coder-model)

## Current Setup (Windows)

- **OS**: Windows 11 Pro 10.0.26100
- **Node**: 24.14.0
- **npm**: 11.12.0
- **OpenClaw**: 2026.3.13
- **Gateway**: ws://127.0.0.1:18789 (loopback)
- **Channel**: Telegram (enabled)
