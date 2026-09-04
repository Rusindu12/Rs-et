"""
External AI providers for RS AI.

RS AI can reply with its own local RS-GPT model, or route the question to an
external AI service (Groq / OpenAI / Gemini / OpenRouter / DeepSeek / any
OpenAI-compatible endpoint) and pass the answer back through the RS AI API —
so the app gets smarter with zero app changes.

Chain strategy: try the external provider first; if it errors/times out,
automatically fall back to the local RS-GPT model.
"""

import os

import requests

# Persona given to external models so their answers come out as "RS AI"
# and in the user's own language (Sinhala in -> Sinhala out).
SYSTEM_PROMPT = (
    "You are RS AI, a friendly AI assistant created by the RS team from Sri Lanka. "
    "You are fluent in Sinhala and English. Always reply in the SAME language the "
    "user uses — Sinhala questions get Sinhala answers. Be concise, warm and helpful."
)


class Provider:
    name = "provider"

    def chat(self, message: str, max_tokens: int, temperature: float) -> str:
        raise NotImplementedError


class LocalRSProvider(Provider):
    """Answers with our own RS-GPT model running in this process."""

    name = "rs-gpt-local"

    def __init__(self, reply_fn):
        self._reply_fn = reply_fn

    def chat(self, message, max_tokens=200, temperature=0.8):
        return self._reply_fn(message, max_tokens, temperature)


class OpenAICompatibleProvider(Provider):
    """Groq / OpenAI / OpenRouter / DeepSeek / Together / Ollama / custom endpoints."""

    def __init__(self, name, base_url, api_key, model, timeout=75):
        self.name = name
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model = model
        self.timeout = timeout

    def chat(self, message, max_tokens=512, temperature=0.7):
        r = requests.post(
            f"{self.base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": self.model,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": message},
                ],
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
            timeout=self.timeout,
        )
        r.raise_for_status()
        data = r.json()
        return data["choices"][0]["message"]["content"].strip()


class GeminiProvider(Provider):
    """Google AI Studio — native generateContent API."""

    def __init__(self, api_key, model="gemini-2.0-flash", timeout=75):
        self.name = f"gemini/{model}"
        self.api_key = api_key
        self.model = model
        self.timeout = timeout

    def chat(self, message, max_tokens=512, temperature=0.7):
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self.model}:generateContent?key={self.api_key}"
        )
        r = requests.post(
            url,
            json={
                "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
                "contents": [{"role": "user", "parts": [{"text": message}]}],
                "generationConfig": {
                    "maxOutputTokens": max_tokens,
                    "temperature": temperature,
                },
            },
            timeout=self.timeout,
        )
        r.raise_for_status()
        data = r.json()
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()


# name -> (base_url, default_model, env keys to probe)
PRESETS = {
    "groq": (
        "https://api.groq.com/openai/v1",
        "llama-3.3-70b-versatile",
        ["GROQ_API_KEY"],
    ),
    "openai": (
        "https://api.openai.com/v1",
        "gpt-4o-mini",
        ["OPENAI_API_KEY"],
    ),
    "openrouter": (
        "https://openrouter.ai/api/v1",
        "meta-llama/llama-3.3-70b-instruct",
        ["OPENROUTER_API_KEY"],
    ),
    "deepseek": (
        "https://api.deepseek.com/v1",
        "deepseek-chat",
        ["DEEPSEEK_API_KEY"],
    ),
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
    return OpenAICompatibleProvider(f"{name}/{model}", base, key, model)


def build_chain(local_reply_fn, mode=None):
    """Provider failover chain, in priority order.

    RS_PROVIDER values:
      local                                  -> local RS-GPT only
      groq / openai / openrouter / deepseek  -> that service first, local fallback
      gemini                                 -> Google AI Studio, local fallback
      custom                                 -> RS_BASE_URL + RS_EXT_MODEL + RS_API_KEY
      auto (default)                         -> first provider with a configured key
    """
    local = LocalRSProvider(local_reply_fn)
    mode = (mode or os.environ.get("RS_PROVIDER", "auto")).strip().lower()
    external = None

    if mode in PRESETS:
        base, default_model, keys = PRESETS[mode]
        key = _find_key("RS_API_KEY", *keys)
        if key:
            external = _openai_preset(mode, key)
        else:
            print(f"[providers] RS_PROVIDER={mode} but no API key -> local only")

    elif mode == "gemini":
        key = _find_key("RS_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY")
        if key:
            external = GeminiProvider(
                key, os.environ.get("RS_EXT_MODEL") or "gemini-2.0-flash"
            )
        else:
            print("[providers] RS_PROVIDER=gemini but no API key -> local only")

    elif mode == "custom":
        key = _find_key("RS_API_KEY")
        base = os.environ.get("RS_BASE_URL", "").strip()
        model = os.environ.get("RS_EXT_MODEL") or "custom-model"
        if key and base:
            external = OpenAICompatibleProvider(f"custom/{model}", base, key, model)
        else:
            print("[providers] custom mode needs RS_BASE_URL + RS_API_KEY -> local only")

    elif mode == "auto":
        # provider-specific keys, smartest free tiers first
        groq_key = _find_key("GROQ_API_KEY")
        gem_key = _find_key("GEMINI_API_KEY", "GOOGLE_API_KEY")
        if groq_key:
            external = _openai_preset("groq", groq_key)
        elif gem_key:
            external = GeminiProvider(
                gem_key, os.environ.get("RS_EXT_MODEL") or "gemini-2.0-flash"
            )
        else:
            for name in ("openai", "openrouter", "deepseek"):
                _, _, keys = PRESETS[name]
                k = _find_key(*keys)
                if k:
                    external = _openai_preset(name, k)
                    break
        if external is None:
            # only a generic RS_API_KEY set -> default to Groq (fast + generous free tier)
            generic = _find_key("RS_API_KEY")
            if generic:
                external = _openai_preset("groq", generic)

    elif mode != "local":
        print(f"[providers] unknown RS_PROVIDER '{mode}' -> local only")

    chain = ([external, local] if external is not None else [local])
    print(f"[providers] chain: {' -> '.join(p.name for p in chain)}")
    return chain
