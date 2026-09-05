# RS AI Server — Smart Routing (සිංහල guide)

> ⚠️ **Sandbox note:** Arena live-preview sandbox එකේ external AI API hosts
> (Groq/Gemini/OpenAI...) network-block — ඒ නිසා preview එක local mode එකේයි.
> **ඔයාගේ PC/server/Colab** එකක run කළොත් smart mode එක වැඩ කරයි — පියවර 3යි:
>
> 1. [console.groq.com](https://console.groq.com) → *API Keys* → *Create* (**නොමිලේ**)
> 2. `server/.env.example` copy කරලා `server/.env` කියලා save කරලා key එක දාන්න
> 3. `python server/main.py` → header එකේ ⚡ smart mode කියලා එනවා!

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

## 💸 100% FREE smart mode (no payment, no account!)

API key එකක් configure නැත්නම් chain auto වෙනුවෙන්:
**`pollinations/openai (free)`** — key-less open models (free, https://pollinations.ai)
→ 💡 thinking, 🧠 think harder, 🔬 research synthesis ඔක්කොම **free** වැඩ!
(sandbox-less networks; CI-verified live smoke test)

| FREE option | Setup | Notes |
|---|---|---|
| 🆓 **pollinations** (default fallback) | nothing! | key-less; `RS_FREE_TEXT=0` to disable |
| 🆓 **ollama** (local open models) | `RS_PROVIDER=ollama` + [ollama.com](https://ollama.com) | qwen2.5/llama3.2, PC එකෙන්ම, private |
| 🆓 **Groq/Gemini free tier key** | `server/.env` | fastest quality; free account |

උදා: `docker run -e RS_PROVIDER=ollama -e RS_EXT_MODEL=llama3.2 ...`

## 🎛️ Smart Modes (app/web UI mode chips)

| Mode | කොහොමද වැඩ කරන්නේ | Needs |
|---|---|---|
| 💬 `chat` | Provider chain, text + 📷 image attachments (vision) | vision model = `RS_MODEL_VISION` |
| 💡 `think` | Reasoning model (DeepSeek-R1/o4-mini…) | `RS_MODEL_THINK` or preset |
| 🧠 `think_harder` | Same model, tokens ×2.5, temp ↓ | same |
| 🔬 `research` | Query-gen → web search → page fetch → cited synthesis | external + internet |
| 🎨 `image` | OpenAI images API if `RS_IMAGE_MODEL` set, else FREE key-less Pollinations | none ✅ |

Presets (auto per provider): think → groq:`deepseek-r1-distill-llama-70b`, openai:`o4-mini`,
deepseek:`deepseek-reasoner`; vision → groq:`llama-4-scout-17b`, openai/gemini: default model.
`/chat` body: `{"message","mode","attachments":[...],"history":[{"role","content"}],"stream"}`
response: `{"reply","provider","mode","image_url"?,"sources"?,"latency_ms"}`

## 🧠 Conversation memory

Clients send `history` (last ~10 turns `[{role: user|assistant, content}]`) with each
request — external providers get full context, local model gets a multi-turn prompt.
Web UI එකේ/auto; Android app එකේ/auto. Streaming වලත් (`stream:true`) same.

## 🛡️ Extras

- `RS_RATE_LIMIT_PER_MIN=120` — per-IP rate limit (0 = off; applies to /chat /v1/* /ask)
- GPU auto-detect (cuda තියෙනවා නම් use; `RS_FORCE_CPU=1` to force CPU)

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

- `GET  /` — web chat UI (PWA)
- `GET  /health` — model + provider chain info
- `POST /chat` — full API: `{"message","mode","attachments","stream"}`
- `POST /v1/chat/completions` — OpenAI-compatible (+ `stream: true` SSE ✅)
- `GET  /v1/models` — OpenAI model list (ChatBox/Open WebUI connect)
- `GET  /ask?q=...` — easy GET (iOS Shortcuts / Tasker / browser)
- `GET  /widget-demo` — embeddable widget demo
- `GET  /diagnose` — 🔧 live self-test (per-provider status, key masks, think/vision
  models, device/GPU, python/torch) — deploy එක debug කරනකොට first place to look
- `GET  /static/widget.js` — any website එකට chat bubble (script tag 1)

**Streaming:** `/chat` or `/v1/chat/completions` වල `"stream": true` → SSE
token-by-token (external providers ගෙන් pass-through, local model token loop).

## 🧠 Teach / train (user-driven learning, 100% free)

RS AIට දේවල් ඉගැන්විය හැකියි — web UI 🧠 button / Android app 🧠 button / API:

- `GET/POST /memory` · `DELETE /memory/{idx}` — **instant memory facts** (`{"text":"..."}`).
  Chat/🧠 think/🧠🧠 harder modes වල system prompt එකට auto inject (≤1200 chars).
- `POST /train/write` — `{"text":"..."}` corpus add → `{"ok":true,"corpus_chars":N}`
- `POST /train/run` — `{"steps":150,"lr":3e-4,"include_memory":true}` → **background fine-tune**
  (daemon thread; weights **hot-swap** on finish — restart නැතුව fresh answers).
  Checkpoint: `model/runs/demo/ckpt_ft.pt` (+ `ckpt.pt.bak` backup).
- `GET /train/corpus` · `GET /train/status` — corpus size + live progress (`step/total/loss`).

Auth: `RS_API_TOKEN` set නම් Bearer header / `?token=`, set නැත්නම් keyless ✅
(FREE default — no payment, no accounts).
