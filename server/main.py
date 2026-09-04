"""
RS AI — FastAPI inference server with SMART MODES.

Modes (client selectable): chat | think | think_harder | research | image
  💬 chat          -> provider chain (text + 📷 image attachments for vision models)
  💡 think         -> reasoning model (DeepSeek-R1 / o4-mini / ...) via RS_MODEL_THINK
  🧠 think_harder  -> same, more tokens + lower temperature
  🔬 research      -> multi-step web research with sources (research.py)
  🎨 image         -> image generation (OpenAI images API or free key-less service)

Run:
    pip install -r requirements.txt
    python server/main.py
"""

import base64
import io
import os
import re
import sys
import time
from pathlib import Path

import torch
import sentencepiece as spm
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from model.gpt import GPT, GPTConfig  # noqa: E402

try:
    from . import research
    from .providers import build_chain, generate_image, think_model_for, THINK_PROMPT
except ImportError:
    import research
    from providers import build_chain, generate_image, think_model_for, THINK_PROMPT

CKPT = os.environ.get("RS_CKPT", str(ROOT / "model" / "runs" / "demo" / "ckpt.pt"))
TOKENIZER = os.environ.get("RS_TOKENIZER", None)
MAX_TOKENS_CAP = 512
MODES = ["chat", "think", "think_harder", "research", "image"]


def _load_dotenv():
    """Minimal .env loader (no dependency): KEY=VALUE lines, '#' comments."""
    candidates = (Path(__file__).resolve().parent / ".env", ROOT / ".env")
    for cand in candidates:
        if cand.exists():
            for line in cand.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
            print(f"[server] loaded env from {cand}")
            return


_load_dotenv()

# --------------------------------------------------------------------------- #
# Load local RS-GPT model
# --------------------------------------------------------------------------- #

print(f"[server] loading checkpoint: {CKPT}")
ckpt = torch.load(CKPT, map_location="cpu", weights_only=False)
cfg = GPTConfig(**ckpt["config"])
model = GPT(cfg)
model.load_state_dict(ckpt["model"])
model.eval()
torch.set_num_threads(max(1, os.cpu_count() or 1))

sp_path = TOKENIZER or ckpt.get("tokenizer")
sp = spm.SentencePieceProcessor(model_file=sp_path)
EOS_ID = sp.piece_to_id("<|end|>")
N_PARAMS = model.num_params()
print(f"[server] local model ready — {N_PARAMS:,} params | vocab {cfg.vocab_size} | ctx {cfg.block_size}")


def local_reply(message: str, max_tokens: int = 200, temperature: float = 0.8) -> str:
    prompt = f"<|user|>\n{message.strip()}\n<|assistant|>\n"
    ids = sp.encode(prompt)
    idx = torch.tensor(ids, dtype=torch.long)[None, :]
    with torch.no_grad():
        out = model.generate(idx, max_new_tokens=min(max_tokens, MAX_TOKENS_CAP),
                             temperature=temperature, top_k=50, top_p=0.9,
                             eos_id=EOS_ID)
    text = sp.decode(out[0][len(ids):].tolist())
    for stop in ("<|end|>", "<|user|>"):
        text = text.split(stop)[0]
    return text.strip() or "…"


CHAIN = build_chain(local_reply)

# --------------------------------------------------------------------------- #
# Attachment handling
# --------------------------------------------------------------------------- #

TEXT_EXT = (".txt", ".md", ".json", ".csv", ".log", ".py", ".js", ".ts", ".html",
            ".css", ".xml", ".yaml", ".yml", ".ini", ".toml", ".sh", ".java",
            ".kt", ".c", ".cpp", ".h", ".go", ".rs", ".sql")


def prepare_attachments(atts):
    """Split into (merged_text_parts, images, notes). Caps: 3 files, 4 MB b64 each."""
    parts, images, notes = [], [], []
    for a in (atts or [])[:3]:
        b64 = a.data_b64 or ""
        if len(b64) > 4_200_000:
            notes.append(f"⚠️ '{a.name}' ලොකු වැඩියි (max ~3MB)")
            continue
        if a.kind == "image":
            images.append({"kind": "image", "mime": a.mime, "data_b64": b64})
            continue
        raw = b""
        try:
            raw = base64.b64decode(b64)
        except Exception:
            pass
        txt = ""
        if a.name.lower().endswith(".pdf"):
            try:
                from pypdf import PdfReader  # optional dep
                reader = PdfReader(io.BytesIO(raw))
                txt = "\n".join((p.extract_text() or "") for p in reader.pages[:8])
            except Exception:
                notes.append(f"⚠️ '{a.name}' PDF කියවන්න බැරි වුණා")
        else:
            try:
                txt = raw.decode("utf-8", errors="replace")
            except Exception:
                txt = ""
        if txt.strip():
            parts.append(f"[📎 file: {a.name}]\n{txt[:6000]}")
        else:
            notes.append(f"⚠️ '{a.name}' text extract කරන්න බැරි වුණා")
    if atts and len(atts) > 3:
        notes.append("⚠️ files 3කට වඩා නොගත්තා")
    return parts, images, notes


# --------------------------------------------------------------------------- #
# Mode-aware reply engine
# --------------------------------------------------------------------------- #

def _notes_block(notes):
    return ("\n".join(notes) + "\n\n") if notes else ""


def smart_reply(message, mode, atts, max_tokens, temperature):
    parts, images, notes = prepare_attachments(atts)
    full_msg = ("\n\n".join(parts + [message])) if parts else message
    prefix = _notes_block(notes)

    # 🎨 IMAGE
    if mode == "image":
        prompt = message.strip() or "beautiful sri lankan landscape, digital art"
        reply, url, prov = generate_image(prompt, CHAIN)
        return {"reply": prefix + reply, "provider": prov, "image_url": url, "mode": mode}

    # 🔬 DEEP RESEARCH
    if mode == "research":
        reply, sources, prov = research.run_research(CHAIN, full_msg)
        if reply is None:
            fb = local_reply(full_msg, min(max_tokens, 300), temperature)
            return {
                "reply": prefix + "🔬 Web research එකට smart mode (Groq/Gemini key) + internet ඕන. Local model එකෙන්:\n\n" + fb,
                "provider": "rs-gpt-local", "mode": mode,
                "sources": sources or None,
            }
        return {"reply": prefix + reply, "provider": prov, "sources": sources, "mode": mode}

    # 💡🧠 THINK / THINK HARDER
    if mode in ("think", "think_harder"):
        harder = mode == "think_harder"
        want_tokens = min(int(max_tokens * (2.5 if harder else 1.5)), 2000)
        want_temp = 0.5 if harder else 0.6
        for p in CHAIN:
            try:
                if p.family == "local":
                    note = ("💡 Thinking modes වලට smart mode ඕන "
                            "(Groq free key → server/.env). Local උත්තරය:\n\n")
                    return {"reply": prefix + note + p.chat(full_msg, max_tokens, temperature),
                            "provider": p.name, "mode": mode}
                tm = think_model_for(p)
                reply = p.chat(full_msg, want_tokens, want_temp,
                               system=THINK_PROMPT, model_override=tm)
                return {"reply": prefix + reply, "provider": f"{p.key}/{tm}", "mode": mode}
            except Exception as e:  # noqa: BLE001
                print(f"[modes] think via {p.name} failed: {e!r}")
        return {"reply": prefix + "⚠️ providers අසාර්ථකයි.", "provider": "none", "mode": mode}

    # 💬 CHAT (normal) — attachments: images need a vision-capable external provider
    img_note = ""
    for p in CHAIN:
        try:
            if images and p.family == "local":
                img_note = ("📷 Photos analyze කරන්න smart mode ඕන (vision model — "
                            "Groq/Gemini free key). දැනට text විතරයි:\n\n")
                return {"reply": prefix + img_note + p.chat(full_msg, max_tokens, temperature),
                        "provider": p.name, "mode": mode}
            return {"reply": prefix + p.chat(full_msg, max_tokens, temperature,
                                             attachments=images or None),
                    "provider": p.name, "mode": mode}
        except Exception as e:  # noqa: BLE001
            print(f"[modes] {p.name} failed: {e!r} -> next")
    return {"reply": prefix + "⚠️ සියලුම providers අසාර්ථකයි.", "provider": "none", "mode": mode}


# --------------------------------------------------------------------------- #
# API
# --------------------------------------------------------------------------- #

app = FastAPI(title="RS AI", version="1.3.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/static", StaticFiles(directory=str(Path(__file__).resolve().parent / "static")), name="static")


def _require_token(authorization: str | None) -> None:
    tok = os.environ.get("RS_API_TOKEN")
    if tok and authorization != f"Bearer {tok}":
        raise HTTPException(status_code=401, detail="invalid or missing API token (RS_API_TOKEN)")


class Attachment(BaseModel):
    name: str = "file"
    kind: str = "file"          # "image" | "file"
    mime: str = "text/plain"
    data_b64: str = ""


class ChatRequest(BaseModel):
    message: str
    mode: str = "chat"          # chat | think | think_harder | research | image
    attachments: list[Attachment] = []
    max_tokens: int = 400
    temperature: float = 0.8
    top_p: float = 0.9


@app.get("/health")
def health():
    return {
        "status": "ok",
        "local_model": "RS-GPT",
        "params": N_PARAMS,
        "vocab": cfg.vocab_size,
        "context": cfg.block_size,
        "providers": [p.name for p in CHAIN],
        "active": CHAIN[0].name,
        "modes": MODES,
    }


@app.post("/chat")
def chat(req: ChatRequest, authorization: str | None = Header(default=None)):
    _require_token(authorization)
    t0 = time.time()
    mode = (req.mode or "chat").lower()
    if mode not in MODES:
        mode = "chat"
    result = smart_reply(req.message, mode, req.attachments, req.max_tokens, req.temperature)
    result["latency_ms"] = int((time.time() - t0) * 1000)
    return result


class OAIMessage(BaseModel):
    role: str
    content: str


class OAIRequest(BaseModel):
    model: str = "rs-gpt"
    messages: list[OAIMessage]
    max_tokens: int = 400
    temperature: float = 0.8


@app.post("/v1/chat/completions")
def openai_chat(req: OAIRequest, authorization: str | None = Header(default=None)):
    _require_token(authorization)
    user_msgs = [m.content for m in req.messages if m.role == "user"]
    message = user_msgs[-1] if user_msgs else ""
    result = smart_reply(message, "chat", [], min(req.max_tokens, MAX_TOKENS_CAP), req.temperature)
    return {
        "id": f"chatcmpl-{int(time.time())}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": req.model,
        "provider": result["provider"],
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": result["reply"]},
            "finish_reason": "stop",
        }],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }


CHAT_HTML = r"""<!DOCTYPE html>
<html lang="si">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<title>RS AI — සිංහල AI Chat</title>
<link rel="manifest" href="/static/manifest.webmanifest">
<meta name="theme-color" content="#0f172a">
<link rel="apple-touch-icon" href="/static/icon-192.png">
<link rel="icon" type="image/png" href="/static/icon-192.png">
<style>
  * { box-sizing: border-box; margin: 0; }
  body {
    font-family: 'Segoe UI', 'Noto Sans Sinhala', system-ui, sans-serif;
    background: linear-gradient(160deg, #0f172a 0%, #1e1b4b 100%);
    color: #e2e8f0; height: 100dvh; display: flex; flex-direction: column;
  }
  header {
    padding: 12px 16px; display: flex; align-items: center; gap: 12px;
    background: rgba(15,23,42,.75); backdrop-filter: blur(8px);
    border-bottom: 1px solid rgba(148,163,184,.15);
  }
  .logo {
    width: 40px; height: 40px; border-radius: 12px; display: grid; place-items: center;
    font-size: 20px; background: linear-gradient(135deg,#7c3aed,#4f46e5);
  }
  header h1 { font-size: 18px; font-weight: 700; }
  header .sub { font-size: 12px; color: #94a3b8; }
  .dot { width:8px; height:8px; border-radius:50%; background:#4ade80; display:inline-block; margin-right:5px;
         box-shadow: 0 0 8px #4ade80; }
  #chat { flex: 1; overflow-y: auto; padding: 16px 14px 8px; display: flex; flex-direction: column; gap: 10px; }
  .msg { max-width: 84%; padding: 11px 15px; border-radius: 18px; line-height: 1.55;
         font-size: 15px; white-space: pre-wrap; word-wrap: break-word; animation: pop .25s ease; }
  @keyframes pop { from { opacity:0; transform: translateY(6px);} to { opacity:1; } }
  .user { align-self: flex-end; background: linear-gradient(135deg,#7c3aed,#4f46e5);
          color: white; border-bottom-right-radius: 5px; }
  .bot  { align-self: flex-start; background: #1e293b; border: 1px solid rgba(148,163,184,.12);
          border-bottom-left-radius: 5px; }
  .bot img { max-width: 100%; border-radius: 10px; display: block; }
  .sources { margin-top: 8px; font-size: 12px; color: #94a3b8; }
  .sources a { color: #a78bfa; text-decoration: none; display: block; padding: 2px 0; }
  .mrow { display:flex; gap:6px; overflow-x:auto; padding: 4px 12px 8px; scrollbar-width:none; }
  .mrow::-webkit-scrollbar { display:none; }
  .mchip { flex:0 0 auto; background:#16203a; border:1px solid rgba(148,163,184,.22); color:#cbd5e1;
           padding:7px 12px; border-radius:999px; font-size:13px; cursor:pointer; }
  .mchip.on { background: linear-gradient(135deg,#7c3aed,#4f46e5); color:#fff; border-color: transparent; }
  .mchip.spk { margin-left:auto; }
  .mchip.on.spk { background:#065f46; }
  .attrow { display:flex; gap:6px; flex-wrap:wrap; padding: 0 12px 6px; }
  .attchip { background:#312e81; color:#e0e7ff; font-size:12px; padding:6px 10px; border-radius:8px;
             display:flex; gap:6px; align-items:center; }
  .attchip b { cursor:pointer; color:#f87171; }
  footer { padding: 8px 10px; background: rgba(15,23,42,.92); border-top: 1px solid rgba(148,163,184,.15);
           display: flex; gap: 6px; align-items: flex-end; }
  .ibtn {
    background: #1e293b; border: 1px solid rgba(148,163,184,.18); color: #cbd5e1;
    width: 42px; height: 42px; border-radius: 50%; font-size: 17px; cursor: pointer; flex: 0 0 auto;
  }
  .ibtn.rec { border-color:#f87171; color:#f87171; }
  input#inp {
    flex: 1; min-width: 60px; background: #1e293b; border: 1px solid rgba(148,163,184,.25); border-radius: 22px;
    padding: 12px 16px; color: #e2e8f0; font-size: 15px; outline: none;
  }
  input#inp:focus { border-color: #7c3aed; }
  #send {
    background: linear-gradient(135deg,#7c3aed,#4f46e5); border: none; color: white;
    width: 44px; height: 44px; border-radius: 50%; font-size: 18px; cursor: pointer; flex: 0 0 auto;
  }
  #send:disabled { opacity: .5; }
  .typing { display:inline-flex; gap:4px; padding: 14px 16px; }
  .typing span { width:7px; height:7px; border-radius:50%; background:#94a3b8; animation: blink 1.2s infinite; }
  .typing span:nth-child(2){ animation-delay:.2s } .typing span:nth-child(3){ animation-delay:.4s }
  @keyframes blink { 0%,60%,100%{opacity:.3} 30%{opacity:1} }
</style>
</head>
<body>
<header>
  <div class="logo">🤖</div>
  <div>
    <h1>RS AI</h1>
    <div class="sub"><span class="dot"></span><span id="subtxt">සබැඳිවෙමින්…</span></div>
  </div>
</header>
<div id="chat">
  <div class="msg bot">ආයුබෝවන්! 👋 මම <b>RS AI</b>. උඩ mode එකක් තෝරන්න — 💬 chat, 💡 thinking, 🔬 research, 🎨 image. Photos/files attach කරන්නත්, 🎙️ voice වලින් අහන්නත් පුළුවන්!</div>
</div>
<div class="mrow" id="modes">
  <div class="mchip on" data-m="chat">💬 Chat</div>
  <div class="mchip" data-m="think">💡 Thinking</div>
  <div class="mchip" data-m="think_harder">🧠 Think harder</div>
  <div class="mchip" data-m="research">🔬 Deep research</div>
  <div class="mchip" data-m="image">🎨 Create image</div>
  <div class="mchip spk" id="spk">🔊</div>
</div>
<div class="attrow" id="atts"></div>
<footer>
  <button class="ibtn" id="bfile" title="Files">📁</button>
  <button class="ibtn" id="bimg" title="Photos">🖼️</button>
  <button class="ibtn" id="bcam" title="Camera">📷</button>
  <button class="ibtn" id="bmic" title="Voice">🎙️</button>
  <input id="inp" placeholder="මෙසේජ් එකක් ලියන්න…" autocomplete="off">
  <button id="send" onclick="send()">➤</button>
</footer>
<input type="file" id="ffile" hidden accept=".txt,.md,.json,.csv,.log,.py,.js,.ts,.html,.css,.xml,.yaml,.yml,.ini,.toml,.sh,.java,.kt,.c,.cpp,.go,.rs,.sql,.pdf">
<input type="file" id="fimg" hidden accept="image/*">
<input type="file" id="fcam" hidden accept="image/*" capture="environment">
<script>
const chat = document.getElementById('chat');
const inp = document.getElementById('inp');
const sendBtn = document.getElementById('send');
let mode = 'chat';
let atts = [];          // {name,kind,mime,data_b64}
let speakOn = false;

inp.addEventListener('keydown', e => { if (e.key === 'Enter') send(); });

// optional API token (?token=XXXX once)
const qs = new URLSearchParams(location.search);
if (qs.get('token')) {
  localStorage.setItem('rsai_token', qs.get('token'));
  history.replaceState({}, '', location.pathname);
}
function authHeaders() {
  const t = localStorage.getItem('rsai_token');
  return t ? { 'Authorization': 'Bearer ' + t } : {};
}

// mode chips
document.getElementById('modes').addEventListener('click', e => {
  const c = e.target.closest('.mchip');
  if (!c || c.id === 'spk') return;
  document.querySelectorAll('#modes .mchip').forEach(x => x.classList.remove('on'));
  c.classList.add('on');
  mode = c.dataset.m;
  inp.placeholder = mode === 'image' ? 'ඇඳන්න ඕන දේ ලියන්න… 🎨'
                  : mode === 'research' ? '🔬 research කරන මාතෘකාව…'
                  : 'මෙසේජ් එකක් ලියන්න…';
  inp.focus();
});

// speaker toggle
const spk = document.getElementById('spk');
spk.onclick = () => {
  speakOn = !speakOn;
  spk.classList.toggle('on', speakOn);
  if (!speakOn && window.speechSynthesis) speechSynthesis.cancel();
};
function speak(text) {
  if (!speakOn || !window.speechSynthesis) return;
  const u = new SpeechSynthesisUtterance(text.slice(0, 900));
  u.lang = /[\u0D80-\u0DFF]/.test(text) ? 'si-LK' : 'en-US';
  speechSynthesis.speak(u);
}

// attachments
const ffile = document.getElementById('ffile');
const fimg = document.getElementById('fimg');
const fcam = document.getElementById('fcam');
document.getElementById('bfile').onclick = () => ffile.click();
document.getElementById('bimg').onclick = () => fimg.click();
document.getElementById('bcam').onclick = () => fcam.click();
[ffile, fimg, fcam].forEach(f => f.addEventListener('change', () => {
  const file = f.files[0];
  f.value = '';
  if (!file) return;
  if (atts.length >= 3) { add('⚠️ files 3ක් දක්වායි', 'bot'); return; }
  if (file.size > 3 * 1024 * 1024) { add(`⚠️ '${file.name}' ලොකු වැඩියි (max 3MB)`, 'bot'); return; }
  const rd = new FileReader();
  rd.onload = () => {
    const b64 = String(rd.result).split(',')[1] || '';
    atts.push({ name: file.name, kind: file.type.startsWith('image/') ? 'image' : 'file',
                mime: file.type || 'application/octet-stream', data_b64: b64 });
    renderAtts();
  };
  rd.readAsDataURL(file);
}));
function renderAtts() {
  const row = document.getElementById('atts');
  row.innerHTML = '';
  atts.forEach((a, i) => {
    const c = document.createElement('div');
    c.className = 'attchip';
    c.innerHTML = `${a.kind === 'image' ? '🖼️' : '📄'} ${a.name.slice(0, 22)}`;
    const x = document.createElement('b');
    x.textContent = ' ✕';
    x.onclick = () => { atts.splice(i, 1); renderAtts(); };
    c.appendChild(x);
    row.appendChild(c);
  });
}

// voice input
const bmic = document.getElementById('bmic');
let recog = null;
if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  recog = new SR();
  recog.lang = 'si-LK';
  recog.interimResults = false;
  recog.onresult = e => { inp.value = e.results[0][0].transcript; inp.focus(); };
  recog.onend = () => bmic.classList.remove('rec');
}
bmic.onclick = () => {
  if (!recog) { add('🎙️ මේ browser එකේ voice input නැහැ (Chrome try කරන්න)', 'bot'); return; }
  try { recog.start(); bmic.classList.add('rec'); } catch (e) { recog.stop(); }
};

fetch('/health').then(r => r.json()).then(h => {
  const el = document.getElementById('subtxt');
  el.textContent = (h.active && h.active !== 'rs-gpt-local')
    ? '⚡ smart · ' + h.active : 'සබැඳි · Sinhala + English · RS-GPT';
}).catch(() => { document.getElementById('subtxt').textContent = 'සබැඳි'; });

function add(text, cls) {
  const d = document.createElement('div');
  d.className = 'msg ' + cls;
  d.textContent = text;
  chat.appendChild(d);
  chat.scrollTop = chat.scrollHeight;
  return d;
}
function typingBubble() {
  const labels = { chat: 'ටයිප් කරමින්', think: '💡 හිතමින්', think_harder: '🧠 ගැඹුරුව හිතමින්',
                   research: '🔬 research කරමින්', image: '🎨 image හදමින්' };
  const t = document.createElement('div');
  t.className = 'msg bot typing';
  t.title = labels[mode] || '';
  t.innerHTML = '<span></span><span></span><span></span>&nbsp;' + (labels[mode] || '');
  chat.appendChild(t);
  chat.scrollTop = chat.scrollHeight;
  return t;
}

async function send() {
  const text = inp.value.trim();
  if (!text && atts.length === 0) return;
  if (text) add(text + (atts.length ? `\n📎 ${atts.length} attachment(s)` : ''), 'user');
  else add(`📎 ${atts.length} attachment(s)`, 'user');
  inp.value = '';
  const payload = { message: text || '(attachment)', mode, attachments: atts };
  atts = []; renderAtts();
  sendBtn.disabled = true;
  const t = typingBubble();
  try {
    const r = await fetch('/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify(payload)
    });
    if (r.status === 401) {
      t.remove();
      add('🔑 API token එක වැරදියි — URL එකට ?token=XXXX දාලා ආයේ open කරන්න', 'bot');
      return;
    }
    const j = await r.json();
    t.remove();
    if (j.image_url) {
      const d = add(j.reply || '🎨', 'bot');
      const img = document.createElement('img');
      img.loading = 'lazy';
      img.src = j.image_url;
      img.onclick = () => window.open(j.image_url, '_blank');
      d.appendChild(document.createElement('br'));
      d.appendChild(img);
    } else {
      add(j.reply || '…', 'bot');
    }
    if (j.sources && j.sources.length) {
      const s = add('', 'bot');
      s.innerHTML = '<div class="sources"><b>📚 මූලාශ්‍ර</b></div>';
      j.sources.forEach(x => {
        const a = document.createElement('a');
        a.href = x.url; a.target = '_blank';
        a.textContent = '• ' + x.title;
        s.querySelector('.sources').appendChild(a);
      });
    }
    chat.scrollTop = chat.scrollHeight;
    speak(j.reply || '');
  } catch (e) {
    t.remove();
    add('⚠️ දෝෂයක්: ' + e.message, 'bot');
  }
  sendBtn.disabled = false;
}
</script>
</body>
</html>
"""


@app.get("/", response_class=HTMLResponse)
def home():
    return CHAT_HTML


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
