# OpenClaw Rate Limit Fix Guide

## Problem: 429 Rate Limit Errors

When you see errors like:
```
429 All credentials for model xxx are cooling down
429 Rate limit exceeded
```

### Root Cause

**OpenClaw Bug #28925**: 429 errors do NOT automatically trigger fallback models. The agent retries the same rate-limited model instead of switching to a fallback.

---

## Quick Fixes

### Option 1: Restart Gateway (Fastest)
```bash
openclaw gateway restart
```
This clears the rate limit cooldown timer.

### Option 2: Switch to Free Model
```powershell
# Run the workaround script
powershell -ExecutionPolicy Bypass -File "C:\Users\filip\dev\openclaw-setup\config\fix-rate-limit-wrapper.ps1" -Action switch

# Then restart gateway
openclaw gateway restart
```

### Option 3: Disable Memory Search (Reduces API Calls)
```bash
openclaw config set agents.defaults.memorySearch.enabled false
```

---

## Configured Fallback Models (5 Free Models)

After applying `fix-rate-limit.ps1`, you have these fallbacks:

| Model | Provider | Context | Notes |
|-------|----------|---------|-------|
| `openrouter/free` | OpenRouter | 200k | Auto-selects best free model |
| `openrouter/nvidia/nemotron-3-super-120b-a12b:free` | OpenRouter | 200k | 120B params, good quality |
| `openrouter/meta-llama/llama-3-8b-instruct:free` | OpenRouter | 128k | Fast, efficient |
| `openrouter/google/gemma-7b-it:free` | OpenRouter | 64k | Google's open model |
| `openrouter/microsoft/phi-3-mini-128k-instruct:free` | OpenRouter | 128k | 128k context, compact |

### Primary Model
- **`qwen-portal/coder-model`** - Qwen Portal OAuth (local, no rate limits)

---

## Scripts Created

| Script | Purpose |
|--------|---------|
| `config/fix-rate-limit.ps1` | Add 5 free fallback models |
| `config/fix-rate-limit-wrapper.ps1` | Manual workaround tools |

### Usage

```powershell
# Check status
powershell -ExecutionPolicy Bypass -File "config/fix-rate-limit-wrapper.ps1" -Action status

# Switch to free model
powershell -ExecutionPolicy Bypass -File "config/fix-rate-limit-wrapper.ps1" -Action switch

# Restart gateway
powershell -ExecutionPolicy Bypass -File "config/fix-rate-limit-wrapper.ps1" -Action restart

# Disable memory search (reduces API calls)
powershell -ExecutionPolicy Bypass -File "config/fix-rate-limit-wrapper.ps1" -Action disable-fallback
```

---

## Prevention

### 1. Use Qwen Portal as Primary
Qwen Portal uses OAuth with higher rate limits than API keys.

### 2. Enable Fallbacks
Already configured with 5 free models.

### 3. Monitor Usage
```bash
openclaw models status
openclaw status --deep
```

### 4. Reduce Unnecessary API Calls
- Disable memory search if not using semantic recall
- Use compaction mode: `safeguard` (already enabled)
- Batch requests when possible

---

## Known Issues

| Issue | Status | Workaround |
|-------|--------|------------|
| #28925: 429 doesn't trigger fallback | Open (Bug) | Restart gateway |
| #5744: Single model blocks provider | Open | Cross-provider fallbacks |
| Memory search requires API keys | N/A | Disable or configure embeddings |

---

## Provider Rate Limits

### Qwen Portal (Primary)
- OAuth-based authentication
- Higher rate limits than API keys
- Expires in ~1 hour (auto-renewable)

### OpenRouter Free Tier
- Shared rate limits across all free users
- Varies by model
- Best effort availability

---

## Emergency Recovery

If all else fails:

```bash
# 1. Stop gateway
openclaw gateway stop

# 2. Clear session cache
Remove-Item "$env:USERPROFILE\.openclaw\agents\*\sessions\*.json" -Force

# 3. Restart fresh
openclaw gateway start

# 4. Verify
openclaw status
```

---

## References

- GitHub Issue #28925: 429 rate limit error does not trigger fallback model
- OpenClaw Docs: https://docs.openclaw.ai/faq
- OpenRouter Free Models: https://openrouter.ai/models
