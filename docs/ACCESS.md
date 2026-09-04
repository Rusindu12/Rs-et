# RS AI — ඕනම තැනකින් Access 🌍 (Deploy + PWA + API + Token)

RS AI server එක **public internet** එකට දාලා, ඕනම device එකකින්
(phone/laptop/tablet — app or browser) access කරන විදිය මේ guide එකේ.

Server එකේ built-in:
* 🌐 Web chat UI — same-origin API calls, **any host එකේ auto වැඩ කරයි**
* 📱 **PWA** — browser එකෙන් "Install" කරගන්න පුළුවන් (APK නැතුව, iOS/Windows වලත්)
* 🔌 **OpenAI-compatible API** (`/v1/chat/completions`) — ඕනම client/SDK
* 🔑 Optional **API token** — public deploy එක protect කරන්න

---

## 1️⃣ Deploy කරන තැන් (free tiers)

> 📓 **One-click:** [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Rusindu12/Rs-et/blob/main/notebooks/RS_AI_Colab.ipynb)
> `notebooks/RS_AI_Colab.ipynb` — deps → clone → (optional Groq smart key) → server + Cloudflare public URL.
>
> 🔧 **Live debug tip:** deploy වෙලා ඉන්න ඕනම server එකක් — `https://your-host/diagnose` (per-provider status, latency, keys masked, GPU/device/torch/python).
>
> 💸 **No keys? No wallet?** — smart modes still FREE: chain auto-uses **key-less pollinations** (open models) for 💡🧠🔬 — zero setup. Open-source local: [ollama.com](https://ollama.com) models via `RS_PROVIDER=ollama`. මුදල් ගෙවීම කිසිසේත් නෑ.

### 🥇 Hugging Face Spaces (recommended — free, always-on)

1. [huggingface.co](https://huggingface.co) → account → **New Space** → SDK: **Docker**
2. Repo files upload කරන්න (`Dockerfile`, `server/`, `model/` — `git clone` push is easiest:
   ```bash
   git clone https://huggingface.co/spaces/ඔයාගේ-නම/rs-ai
   # Rs-et repo files මෙතනට copy කරලා
   git add -A && git commit -m "RS AI" && git push
   ```)
3. Space → **Settings → Secrets**:
   - `RS_API_KEY` = ඔයාගේ Groq key එක → smart mode ⚡
   - `RS_API_TOKEN` = ඔයා තෝරන password එකක් (optional, protection)
4. URL එක: `https://ඔයාගේ-නම-rsai.hf.space` ← **මෙතනයි ඔයාගේ public RS AI!**

### 🥈 Render.com (free web service)

- **New → Web Service** → Rs-et repo connect
- Build command: `pip install -r server/requirements.txt torch==2.2.2 "numpy<2"`
- Start command: `uvicorn server.main:app --host 0.0.0.0 --port $PORT`
- Env vars: `RS_PROVIDER=groq`, `RS_API_KEY=gsk_...`, (optional `RS_API_TOKEN`)
- Free tier sleep වෙනවා (cold start ~50s) — හැබැයි නොමිලේ.

### 🥉 Google Colab + Cloudflare tunnel (විනාඩි 2 demo)

```python
# Colab cell එක —
!pip install -q torch==2.2.2 "numpy<2" sentencepiece fastapi "uvicorn[standard]" requests
# repo clone
!git clone -b arena/01a06cd6-rs-et https://github.com/Rusindu12/Rs-et.git /content/rsai
%cd /content/rsai
import os
os.environ["RS_PROVIDER"] = "groq"
os.environ["RS_API_KEY"] = "gsk_ඔයාගේ_key"
# server start (background)
import subprocess, threading
p = subprocess.Popen(["python","-m","uvicorn","server.main:app","--host","0.0.0.0","--port","8000"])
# public tunnel
!wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cf
!chmod +x cf && ./cf tunnel --url http://localhost:8000 &
# → output එකේ එන https://xxxx.trycloudflare.com URL එක තමයි public!
```

### 🏠 Local Wi-Fi (අතේ phone එකට)

`python server/main.py` → phone browser/app එකෙන් `http://<PC-IP>:8000`

---

## 2️⃣ කොහෙම device එකකින්වත් use කරන විදිය

| Client | කොහොමද |
|---|---|
| 📱 Android app | Settings ⚙️ → Server URL = deploy URL + API token field |
| 📱 Phone browser (app වගේම) | URL open කරලා → **"Add to Home Screen"** (PWA install) |
| 🍎 iPhone | Safari → Share → **Add to Home Screen** |
| 💻 Desktop | Chrome/Edge → address bar → **Install icon** |
| 🔌 Programmers | `/v1/chat/completions` — OpenAI SDK compatible |

**Third-party OpenAI-compatible apps** (ChatBox, Typebot, Raycast AI, Open WebUI, LibreChat...):
- Base URL: `https://your-host/v1`
- API Key: `RS_API_TOKEN` එක (නැත්නම් onna ama value)
- Model: `rs-gpt` (server `/v1/models` endpoint එකෙන් list වෙනවා)
- ✅ **Streaming (`stream: true`)** — SSE supported: OpenAI format `/v1/chat/completions`
  සහ RS format `/chat` — app කෑල්ල real-time type-writer effect එකක් ගන්න පුළුවන්

## 🧠 Conversation memory ✅

All clients (web/app/OpenAI clients) ද ග්‍රල්කරන conversation history එක යවයි —
RS AI context මතක තියාගනියයි. Server-side stateless — privacy-friendly.

## 🌐 Website එකකට RS AI දාන්න (1 line)

```html
<script src="https://your-host/static/widget.js"></script>
```

නිල/ demo: `https://your-host/widget-demo` — floating 🤖 bubble එකක් ඕනම site එකක.
Token: `<script src="..." data-token="RS_API_TOKEN"></script>`
Options: `data-mode` (chat/think/...), `data-system` (custom persona prompt) —
widget එකටත් history memory + system persona ✅

## ⚡ Easy GET (Shortcuts/Tasker/browsers)

```
GET /ask?q=ආයුබෝවන්&token=RS_API_TOKEN
→ {"reply": "...", "provider": "..."}
```

**curl:**
```bash
curl -X POST https://your-host/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_RS_API_TOKEN" \
  -d '{"message":"ආයුබෝවන්"}'
```

**Python (OpenAI SDK):**
```python
from openai import OpenAI
client = OpenAI(base_url="https://your-host/v1", api_key="YOUR_RS_API_TOKEN")
print(client.chat.completions.create(
    model="rs-gpt",
    messages=[{"role": "user", "content": "සීගිරිය ගැන කියන්න"}],
).choices[0].message.content)
```

---

## 3️⃣ Security — RS_API_TOKEN

Public වුණාම ඕනම කෙනෙක්ට use කරන්න පුළුවන් වෙනවා. Protect කරන්න:

- Server: `RS_API_TOKEN=MySecret123` set (env/.env/Space secret)
- Web UI: URL එකට `?token=MySecret123` දාලා එකක් open කරලා තියෙනවා නම් auto-remember
- Android app: Settings ⚙️ → **API token** field

Token set කළොත් `/chat` + `/v1/*` endpoints වලට `Authorization: Bearer <token>` අත්‍යවශ්‍යයි
(401 otherwise). `/` web UI එකත්, `/health` එකත් open තියෙනවා (UI load වෙන්න).

**Production note:** CORS දැන් `*` — public production නම් `server/main.py` වල
`allow_origins` එකට ඔයාගේ domain එක විතරක් දාන්න.
