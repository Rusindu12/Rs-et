# RS AI Server — Smart Routing (සිංහල guide)

Server එක දෙකෙන්ම උත්තර දෙයි:

1. **වෙනත් AI service එකක්** (Groq/OpenAI/Gemini/...) — API key එකක් set කළොත්,
   උත්තරේ එතනින් අරන් **RS AI විදියටම** (Sinhala persona එකෙන්) දෙනවා
2. **Local RS-GPT model එක** — key එකක් නැත්නම්, නැත්නම් external එක fail
   වුණොත් automatic fallback

App එකට කිසිම වෙනසක් ඕන නෑ — web UI එකට / APK එකට වැඩ කරන්නේ `/chat` API එකයි.

## Quick start

```bash
python server/main.py
# → http://localhost:8000 (web chat UI එකත් මෙතන)
```

## වෙනත් AI වලින් උත්තර අරගන්න (smart mode ⚡)

### නොමිලේම API key ගන්න පුළුවන් තැන්

| Provider | Key ගන්නෙ | Free tier |
|---|---|---|
| **Groq** (recommended — super fast) | [console.groq.com](https://console.groq.com) | Llama 3.3 70B, free |
| **Gemini** | [aistudio.google.com](https://aistudio.google.com) | gemini-2.0-flash, free |

### Run කරන ආකාර

```bash
# 1) Groq (recommended)
RS_PROVIDER=groq RS_API_KEY=gsk_ඔයාගේ_key එක python server/main.py

# 2) Gemini
RS_PROVIDER=gemini RS_API_KEY=AIza_ඔයාගේ_key එක python server/main.py

# 3) OpenAI / OpenRouter / DeepSeek
RS_PROVIDER=deepseek RS_API_KEY=sk-... python server/main.py

# 4) AUTO mode — env එකේ GROQ_API_KEY / GEMINI_API_KEY / OPENAI_API_KEY
#    වගේ එකක් set නම්, RS_PROVIDER නොකියාත් auto use කරයි
export GROQ_API_KEY=gsk_...
python server/main.py

# 5) ඕනම OpenAI-compatible endpoint එකක් (Ollama, Together, vLLM...)
RS_PROVIDER=custom \
RS_BASE_URL=http://localhost:11434/v1 \
RS_EXT_MODEL=llama3.1 \
RS_API_KEY=anything \
python server/main.py
```

### Env variables

| Variable | අරුත |
|---|---|
| `RS_PROVIDER` | `auto` / `local` / `groq` / `openai` / `gemini` / `openrouter` / `deepseek` / `custom` |
| `RS_API_KEY` | ඕනම provider එකක key එක (provider-specific: `GROQ_API_KEY` etc. වලින්ත් බලනවා) |
| `RS_EXT_MODEL` | external model name එක override කරන්න (default: groq=llama-3.3-70b, gemini=gemini-2.0-flash) |
| `RS_BASE_URL` | custom mode එකේ endpoint |
| `RS_CKPT` | local model checkpoint path |
| `PORT` | server port (default 8000) |

## Behavior

- External provider එකට දෙන system prompt එක: *"You are RS AI... fluent in
  Sinhala and English. Reply in the SAME language the user uses."* → external AI
  එකත් **සිංහලෙන්, RS AI ලෙස** කතා කරයි
- External fail → automatic **local RS-GPT fallback** (server එක කවදාවත් dead වෙන්නේ නෑ)
- හැම response එකකම `provider` field එකෙන් පේනවා උත්තරේ ආවේ කොහෙන්ද කියලා:
```json
{"reply": "ආයුබෝවන්! ...", "provider": "groq/llama-3.3-70b-versatile", "latency_ms": 812}
```
- Web UI header එකේ active engine එක පේනවා (`⚡ smart mode · ...`)

## Endpoints

- `GET  /` — web chat UI
- `GET  /health` — model + provider chain info
- `POST /chat` — `{"message": "...", "max_tokens": 400, "temperature": 0.8}`
- `POST /v1/chat/completions` — OpenAI-compatible
