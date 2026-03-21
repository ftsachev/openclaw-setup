"""Lightweight AI summarization utility — strict token budget.

Priority order: Codex (codex-mini-latest) → Haiku (claude-haiku-4-5-20251001)
Zero-dependency fallback if neither API key is set.

Used by briefing.py and deck scripts for pre-summarizing raw content
before it reaches the agent context.

Budget constraints (non-negotiable):
  - max_tokens: 80 for summaries, 150 for slide narratives
  - Input cap: first 600 chars of content only
  - No retries — fail fast and fall back to truncation
"""

from __future__ import annotations

import os

_CODEX_MODEL = 'codex-mini-latest'
_HAIKU = 'claude-haiku-4-5-20251001'
_MAX_INPUT = 600   # chars — enough context, not bloat
_MAX_TOKENS = 80   # strict ceiling — 1-2 sentence output only
_MAX_TOKENS_SLIDE = 150  # slightly more room for slide body text


def _get_codex_client():
    """Return an OpenAI client pointed at Codex, or None if unavailable."""
    key = os.environ.get('CODEX_API_KEY', '') or os.environ.get('OPENAI_API_KEY', '')
    if not key:
        return None
    try:
        import openai
        return openai.OpenAI(api_key=key)
    except ImportError:
        return None


def _get_haiku_client():
    """Return an Anthropic client or None if unavailable."""
    key = os.environ.get('ANTHROPIC_API_KEY', '')
    if not key:
        return None
    try:
        import anthropic
        return anthropic.Anthropic(api_key=key)
    except ImportError:
        return None


def _call(prompt: str, max_tokens: int) -> str | None:
    """Call Codex first, fall back to Haiku. Returns text or None."""
    # 1. Try Codex
    codex = _get_codex_client()
    if codex:
        try:
            resp = codex.responses.create(
                model=_CODEX_MODEL,
                input=prompt,
                max_output_tokens=max_tokens,
            )
            return resp.output_text.strip()
        except Exception:
            pass  # fall through to Haiku

    # 2. Try Haiku
    haiku = _get_haiku_client()
    if haiku:
        try:
            msg = haiku.messages.create(
                model=_HAIKU,
                max_tokens=max_tokens,
                messages=[{'role': 'user', 'content': prompt}],
            )
            block = msg.content[0]
            text = getattr(block, 'text', None)
            if text:
                return text.strip()
        except Exception:
            pass

    return None


def summarize(content: str, context: str = '', max_words: int = 25) -> str:
    """Summarize content into a single sentence.

    Args:
        content:   Raw text to summarize (capped at _MAX_INPUT internally).
        context:   Optional topic/title hint for better framing.
        max_words: Soft target for output length (not enforced by API).

    Returns:
        1-sentence summary, or first 120 chars of content as fallback.
    """
    if not content or not content.strip():
        return ''

    fallback = content[:120].rstrip() + ('…' if len(content) > 120 else '')

    parts = []
    if context:
        parts.append(f'Topic: {context}')
    parts.append(f'Content:\n{content[:_MAX_INPUT]}')
    parts.append(
        f'Write ONE sentence (max {max_words} words) summarising the key insight. '
        'Plain text only, no bullet points, no preamble.'
    )
    prompt = '\n\n'.join(parts)

    return _call(prompt, _MAX_TOKENS) or fallback


def summarize_findings(findings: list[dict], topic_name: str, max_words: int = 30) -> str:
    """Summarize a list of last30days findings into one briefing sentence.

    Pulls the top 3 findings by engagement, concatenates their content,
    and summarizes the combined signal.

    Args:
        findings:    List of finding dicts (must have 'content', 'engagement_score').
        topic_name:  Used as context hint.
        max_words:   Soft word limit for output.

    Returns:
        Summary sentence, or '' if no findings.
    """
    if not findings:
        return ''

    top = sorted(findings, key=lambda f: f.get('engagement_score', 0), reverse=True)[:3]
    combined = ' | '.join(
        f.get('content', '')[:150].strip()
        for f in top
        if f.get('content', '').strip()
    )
    return summarize(combined, context=topic_name, max_words=max_words)


def generate_slide_narrative(data: dict, topic: str, max_words: int = 40) -> str:
    """Generate a 1-2 sentence executive narrative for a deck slide.

    Converts raw metrics data into a plain-English insight sentence suitable
    for a slide body or exec summary card. Uses slightly higher token budget
    than summarize() to allow for richer framing.

    Args:
        data:      Dict of metrics/KPIs (e.g. {'coverage': 88, 'gap': 12}).
        topic:     Slide title or topic for context.
        max_words: Soft word ceiling.

    Returns:
        Narrative sentence(s), or a plain fallback if AI unavailable.
    """
    if not data:
        return ''

    # Flatten data dict into a compact key=value list
    metrics_str = ', '.join(f'{k}={v}' for k, v in data.items() if v is not None)
    if not metrics_str:
        return ''

    fallback = f'{topic}: {metrics_str[:120]}'

    prompt = (
        f'Slide topic: {topic}\n'
        f'Metrics: {metrics_str[:_MAX_INPUT]}\n\n'
        f'Write 1-2 sentences (max {max_words} words) for an executive security deck. '
        'Lead with the key finding or risk. Be direct and specific. '
        'Plain text only, no bullet points, no preamble.'
    )

    return _call(prompt, _MAX_TOKENS_SLIDE) or fallback
