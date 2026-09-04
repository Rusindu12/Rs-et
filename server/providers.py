"""
External AI providers + smart modes for RS AI.

Modes (web UI / app selectable):
  chat         -> normal reply via provider chain (text+image attachments ok)
  think        -> reasoning model (e.g. DeepSeek-R1 / o4-mini) if configured
  think_harder -> same model, more tokens + lower temperature
  research     -> multi-step web research with sources (see research.py)
  image        -> image generation (OpenAI images API or free Pollinations)

Chain strategy: try the external provider first; on error fall back to local RS-GPT.

Conversation memory: every chat() accepts `history` — a list of
{"role": "user"|"assistant", "content": str} dicts with the recent turns.
Clients (web UI / Android) send it with each request so RS AI remembers context.
"""

import json
import os
from urllib.parse import quote

import requests

# Persona given to external models so their answers come out as "RS AI"
# and in the user's own language (Sinhala in -> Sinhala out).
SYSTEM_PROMPT = (
    "You are RS AI, a friendly AI assistant created by the RS team from Sri Lanka. "
    "You are fluent in Sinhala and English. Always reply in the SAME language the "
    "user uses — Sinhala questions get Sinhala answers. Be concise, warm and helpful."
)

RESEARCH_PROMPT = SYSTEM_PROMPT + (
    " You're in DEEP RESEARCH mode: synthesize the provided sources into a clear "
    "answer, cite them inline like [1], [2], and end with a short මූලාශ්‍ර / Sources list."
)

THINK_PROMPT = SYSTEM_PROMPT + (
    " Think step by step internally, then give a clear, well-structured final answer."
)

POLLINATIONS_URL = "https://image.pollinations.ai/prompt/{prompt}?width=832&height=832&nologo=true&seed={seed}"

# default reasoning models per provider key (override with RS_MODEL_THINK)
THINK_MODELS = {
    "groq": "deepseek-r1-distill-llama-70b",
    "openai": "o4-mini",
    "openrouter": "deepseek/deepseek-r1",
    "deepseek": "deepseek-reasoner",
    "pollinations": "openai",
    "ollama": "qwen2.5:3b",
}
# default vision models per provider key (override with RS_MODEL_VISION)
VISION_MODELS = {
    "groq": "meta-llama/llama-4-scout-17b-16e-instruct",
    "openai": "gpt-4o-mini",
    "openrouter": "openai/gpt-4o-mini",
    "deepseek": "deepseek-chat",
    "pollinations": "openai",
    "ollama": "qwen2.5:3b",
}

_MAX_HISTORY_CHARS = 4000   # per-turn cap before sending history to providers


def clean_history(history):
    """Validate/normalize client history -> [{role, content}]."""
    out = []
    for h in (history or [])[-20:]:
        role = h.get("role") if isinstance(h, dict) else getattr(h, "role", None)
        content = h.get("content") if isinstance(h, dict) else getattr(h, "content", None)
        if role in ("user", "assistant") and content:
            out.append({"role": role, "content": str(content)[:_MAX_HISTORY_CHARS]})
    return out


class Provider:
    name = "provider"
    family = "base"    # "local" | "openai" | "gemini"
    key = ""           # preset key e.g. "groq"

    def chat(self, message, max_tokens=400, temperature=0.7, system=None,
             attachments=None, model_override=None, history=None) -> str:
        raise NotImplementedError


class LocalRSProvider(Provider):
    """Our own RS-GPT model running in this process."""

    name = "rs-gpt-local"
    family = "local"
    key = "local"

    def __init__(self, reply_fn):
        self._reply_fn = reply_fn

    def chat(self, message, max_tokens=200, temperature=0.8, history=None, **kw):
        return self._reply_fn(message, max_tokens, temperature, history=history)


def _openai_user_msg(message, images):
    if images:
        content = [{"type": "text", "text": message}]
        for a in images:
            content.append({
                "type": "image_url",
                "image_url": {"url": f"data:{a['mime']};base64,{a['data_b64']}"},
            })
        return {"role": "user", "content": content}
    return {"role": "user", "content": message}


class OpenAICompatibleProvider(Provider):
    """Groq / OpenAI / OpenRouter / DeepSeek / Together / Ollama / custom endpoints."""

    family = "openai"

    def __init__(self, name, base_url, api_key, model, key="", timeout=90):
        self.name = name
        self.key = key
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model = model
        self.timeout = timeout

    def _headers(self):
        h = {"Content-Type": "application/json"}
        if self.api_key:
            h["Authorization"] = f"Bearer {self.api_key}"
        return h

    def _payload(self, message, max_tokens, temperature, system, attachments,
                 model_override, history):
        model = model_override or self.model
        images = [a for a in (attachments or []) if a.get("kind") == "image"]
        if images:
            model = model_override or vision_model_for(self)
        messages = [{"role": "system", "content": system or SYSTEM_PROMPT}]
        messages.extend(clean_history(history))
        messages.append(_openai_user_msg(message, images))
        return model, {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }

    def chat(self, message, max_tokens=512, temperature=0.7, system=None,
             attachments=None, model_override=None, history=None):
        _, payload = self._payload(message, max_tokens, temperature, system,
                                   attachments, model_override, history)
        r = requests.post(
            f"{self.base_url}/chat/completions",
            headers=self._headers(),
            json=payload,
            timeout=self.timeout,
        )
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"].strip()

    def chat_stream(self, message, max_tokens=512, temperature=0.7, system=None,
                    attachments=None, model_override=None, history=None):
        """Yields content delta strings via SSE (OpenAI stream format)."""
        _, payload = self._payload(message, max_tokens, temperature, system,
                                   attachments, model_override, history)
        payload["stream"] = True
        with requests.post(
            f"{self.base_url}/chat/completions",
            headers=self._headers(),
            json=payload,
            timeout=self.timeout,
            stream=True,
        ) as r:
            r.raise_for_status()
            for line in r.iter_lines(decode_unicode=True):
                if not line or not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    break
                try:
                    delta = json.loads(data)["choices"][0].get("delta", {})
                    chunk = delta.get("content")
                    if chunk:
                        yield chunk
                except (ValueError, KeyError, IndexError):
                    continue

    def generate_image(self, prompt, model=None, timeout=120):
        """OpenAI images API (used when RS_IMAGE_MODEL is set)."""
        r = requests.post(
            f"{self.base_url}/images/generations",
            headers=self._headers(),
            json={"model": model or "dall-e-3", "prompt": prompt, "n": 1,
                  "size": "1024x1024", "response_format": "url"},
            timeout=timeout,
        )
        r.raise_for_status()
        return r.json()["data"][0]["url"]


def _gemini_contents(message, history, images):
    """Gemini contents list: roles must alternate user/model; images attach to last user turn."""
    contents = []
    for h in clean_history(history):
        contents.append({
            "role": "model" if h["role"] == "assistant" else "user",
            "parts": [{"text": h["content"]}],
        })
    parts = [{"text": message}]
    for a in (images or []):
        if a.get("kind") == "image":
            parts.append({"inline_data": {"mime_type": a["mime"], "data": a["data_b64"]}})
    contents.append({"role": "user", "parts": parts})
    return contents


class GeminiProvider(Provider):
    """Google AI Studio — native generateContent API."""

    family = "gemini"

    def __init__(self, api_key, model="gemini-2.0-flash", key="gemini", timeout=90):
        self.name = f"gemini/{model}"
        self.key = key
        self.api_key = api_key
        self.model = model
        self.timeout = timeout

    def _payload(self, message, max_tokens, temperature, system,
                 attachments, history):
        images = [a for a in (attachments or []) if a.get("kind") == "image"]
        return {
            "systemInstruction": {"parts": [{"text": system or SYSTEM_PROMPT}]},
            "contents": _gemini_contents(message, history, images),
            "generationConfig": {"maxOutputTokens": max_tokens, "temperature": temperature},
        }

    def chat(self, message, max_tokens=512, temperature=0.7, system=None,
             attachments=None, model_override=None, history=None):
        model = model_override or self.model
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={self.api_key}"
        )
        r = requests.post(
            url,
            json=self._payload(message, max_tokens, temperature, system,
                               attachments, history),
            timeout=self.timeout,
        )
        r.raise_for_status()
        return r.json()["candidates"][0]["content"]["parts"][0]["text"].strip()

    def chat_stream(self, message, max_tokens=512, temperature=0.7, system=None,
                    attachments=None, model_override=None, history=None):
        """Yields content delta strings via Gemini SSE (streamGenerateContent)."""
        model = model_override or self.model
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:streamGenerateContent?alt=sse&key={self.api_key}"
        )
        with requests.post(
            url,
            json=self._payload(message, max_tokens, temperature, system,
                               attachments, history),
            timeout=self.timeout,
            stream=True,
        ) as r:
            r.raise_for_status()
            for line in r.iter_lines(decode_unicode=True):
                if not line or not line.startswith("data:"):
                    continue
                try:
                    j = json.loads(line[5:].strip())
                    for pt in j["candidates"][0]["content"]["parts"]:
                        if "text" in pt:
                            yield pt["text"]
                except (ValueError, KeyError, IndexError):
                    continue


def think_model_for(p: Provider) -> str:
    return os.environ.get("RS_MODEL_THINK") or THINK_MODELS.get(p.key) or getattr(p, "model", "")


def vision_model_for(p: Provider) -> str:
    return os.environ.get("RS_MODEL_VISION") or VISION_MODELS.get(p.key) or getattr(p, "model", "")


def generate_image(prompt: str, chain):
    """Returns (reply_text, image_url, provider_name).

    If RS_IMAGE_MODEL is set and an OpenAI-compatible provider exists -> images API.
    Otherwise -> free keyless Pollinations URL (client loads it directly)."""
    import random
    import re

    for p in chain:
        if p.family == "openai" and os.environ.get("RS_IMAGE_MODEL"):
            try:
                url = p.generate_image(prompt, model=os.environ["RS_IMAGE_MODEL"])
                reply = f"මෙන්න ඔයාගේ image එක 🎨 — \"{prompt}\""
                return reply, url, f"{p.key}/{os.environ['RS_IMAGE_MODEL']}"
            except Exception as e:  # noqa: BLE001
                print(f"[providers] image gen via {p.name} failed: {e!r} -> pollinations")

    url = POLLINATIONS_URL.format(prompt=quote(prompt), seed=random.randint(1, 999999))
    lang_si = bool(re.search(r"[\u0D80-\u0DFF]", prompt))
    reply = (
        f"මෙන්න ඔයාගේ image එක 🎨 — \"{prompt}\"\n(ස්ටුටි: RS API key එකක් නැති free image service එකෙන්)"
        if lang_si else
        f"Here's your image 🎨 — \"{prompt}\"\n(via the free, key-less Pollinations service)"
    )
    return reply, url, "pollinations/free"


# name -> (base_url, default_model, env keys to probe)
PRESETS = {
    "groq": ("https://api.groq.com/openai/v1", "llama-3.3-70b-versatile", ["GROQ_API_KEY"]),
    "openai": ("https://api.openai.com/v1", "gpt-4o-mini", ["OPENAI_API_KEY"]),
    "openrouter": ("https://openrouter.ai/api/v1", "meta-llama/llama-3.3-70b-instruct", ["OPENROUTER_API_KEY"]),
    "deepseek": ("https://api.deepseek.com/v1", "deepseek-chat", ["DEEPSEEK_API_KEY"]),
}


def _find_key(*env_names):
    for n in env_names:
        v = os.environ.get(n)
        if v and v.strip():
            return v.strip()
    return None


def _openai_preset(name, key, model_override=None):
    base, default_model, _ = PRESETS[name]
    model = model_override or os.environ.get("RS_EXT_MODEL") or default_model
    return OpenAICompatibleProvider(f"{name}/{model}", base, key, model, key=name)


def build_chain(local_reply_fn, mode=None):
    """Provider failover chain, in priority order. See server/README.md."""
    local = LocalRSProvider(local_reply_fn)
    mode = (mode or os.environ.get("RS_PROVIDER", "auto")).strip().lower()
    external = None

    if mode in PRESETS:
        _, _, keys = PRESETS[mode]
        key = _find_key("RS_API_KEY", *keys)
        if key:
            external = _openai_preset(mode, key)
        else:
            print(f"[providers] RS_PROVIDER={mode} but no API key -> local only")

    elif mode == "gemini":
        key = _find_key("RS_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY")
        if key:
            external = GeminiProvider(key, os.environ.get("RS_EXT_MODEL") or "gemini-2.0-flash")
        else:
            print("[providers] RS_PROVIDER=gemini but no API key -> local only")

    elif mode == "pollinations":
        external = TextPollinationsProvider(os.environ.get("RS_EXT_MODEL") or "openai")

    elif mode == "ollama":
        base = os.environ.get("RS_OLLAMA_URL", "http://localhost:11434/v1")
        mdl = os.environ.get("RS_EXT_MODEL") or "qwen2.5:3b"
        external = OpenAICompatibleProvider(f"ollama/{mdl}", base, "", mdl, key="ollama")

    elif mode == "custom":
        key = _find_key("RS_API_KEY")
        base = os.environ.get("RS_BASE_URL", "").strip()
        model = os.environ.get("RS_EXT_MODEL") or "custom-model"
        if key and base:
            external = OpenAICompatibleProvider(f"custom/{model}", base, key, model, key="custom")
        else:
            print("[providers] custom mode needs RS_BASE_URL + RS_API_KEY -> local only")

    elif mode == "auto":
        groq_key = _find_key("GROQ_API_KEY")
        gem_key = _find_key("GEMINI_API_KEY", "GOOGLE_API_KEY")
        if groq_key:
            external = _openai_preset("groq", groq_key)
        elif gem_key:
            external = GeminiProvider(gem_key, os.environ.get("RS_EXT_MODEL") or "gemini-2.0-flash")
        else:
            for name in ("openai", "openrouter", "deepseek"):
                _, _, keys = PRESETS[name]
                k = _find_key(*keys)
                if k:
                    external = _openai_preset(name, k)
                    break
        if external is None:
            generic = _find_key("RS_API_KEY")
            if generic:
                external = _openai_preset("groq", generic)
        # 100% FREE key-less smart mode (open models hosted by pollinations.ai)
        if external is None and os.environ.get("RS_FREE_TEXT", "1") != "0":
            print("[providers] no API keys — using FREE key-less pollinations for smart modes")
            external = TextPollinationsProvider(os.environ.get("RS_EXT_MODEL") or "openai")

    elif mode != "local":
        print(f"[providers] unknown RS_PROVIDER '{mode}' -> local only")

    chain = ([external, local] if external is not None else [local])
    print(f"[providers] chain: {' -> '.join(p.name for p in chain)}")
    return chain

class TextPollinationsProvider(Provider):
    """FREE key-less open-model chat — https://text.pollinations.ai (POST /, OpenAI-ish).

    Zero config: no API key. Powers smart modes (think/research) for free when
    no provider key is configured. Set RS_FREE_TEXT=0 to disable.
    """

    family = "openai"
    key = "pollinations"

    def __init__(self, model="openai", timeout=120):
        self.name = f"pollinations/{model} (free)"
        self.model = model
        self.timeout = timeout

    def chat(self, message, max_tokens=512, temperature=0.7, system=None,
             attachments=None, model_override=None, history=None):
        msgs = [{"role": "system", "content": system or SYSTEM_PROMPT}]
        msgs.extend(clean_history(history))
        msgs.append({"role": "user", "content": message})
        r = requests.post(
            "https://text.pollinations.ai/",
            json={"messages": msgs, "model": model_override or self.model,
                  "jsonMode": False},
            timeout=self.timeout,
        )
        r.raise_for_status()
        return r.text.strip()

    def chat_stream(self, message, max_tokens=512, temperature=0.7, system=None,
                    attachments=None, model_override=None, history=None):
        # Pollinations text API has no documented SSE; pseudo-stream the final
        # text in small chunks so clients still get the typewriter UX.
        text = self.chat(message, max_tokens, temperature, system,
                         attachments, model_override, history)
        step = 64
        for i in range(0, len(text), step):
            yield text[i:i + step]


