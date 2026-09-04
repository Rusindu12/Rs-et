"""
RS AI — FastAPI inference server.

Replies come from a provider chain (see providers.py):
  1. an external AI service if configured (Groq/OpenAI/Gemini/custom)
  2. the local RS-GPT model as fallback — always available

Run:
    pip install -r requirements.txt
    python server/main.py
    RS_PROVIDER=groq RS_API_KEY=gsk_... python server/main.py

Endpoints:
    GET  /                      -> web chat UI
    GET  /health                -> model + provider info
    POST /chat                  -> {"message": ..., "max_tokens": ..., "temperature": ...}
    POST /v1/chat/completions   -> OpenAI-compatible endpoint
"""

import os
import sys
import time
from pathlib import Path

import torch
import sentencepiece as spm
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

# repo root on path so "model" package is importable
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from model.gpt import GPT, GPTConfig  # noqa: E402

try:  # run as package (uvicorn server.main:app)
    from .providers import build_chain
except ImportError:  # run as script (python server/main.py)
    from providers import build_chain

CKPT = os.environ.get("RS_CKPT", str(ROOT / "model" / "runs" / "demo" / "ckpt.pt"))
TOKENIZER = os.environ.get("RS_TOKENIZER", None)
MAX_TOKENS_CAP = 512

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


# --------------------------------------------------------------------------- #
# Provider chain (external AI first if configured, local as fallback)
# --------------------------------------------------------------------------- #

CHAIN = build_chain(local_reply)


def smart_reply(message: str, max_tokens: int, temperature: float):
    """Try providers in order; return (reply, provider_name)."""
    last_err = None
    for p in CHAIN:
        try:
            return p.chat(message, max_tokens=max_tokens, temperature=temperature), p.name
        except Exception as e:  # noqa: BLE001 — failover by design
            last_err = e
            print(f"[providers] {p.name} failed: {e!r} -> trying next")
    return f"⚠️ සියලුම providers අසාර්ථකයි: {last_err}", "none"


# --------------------------------------------------------------------------- #
# API
# --------------------------------------------------------------------------- #

app = FastAPI(title="RS AI", version="1.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


class ChatRequest(BaseModel):
    message: str
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
    }


@app.post("/chat")
def chat(req: ChatRequest):
    t0 = time.time()
    reply, provider = smart_reply(req.message, req.max_tokens, req.temperature)
    return {"reply": reply, "provider": provider, "latency_ms": int((time.time() - t0) * 1000)}


class OAIMessage(BaseModel):
    role: str
    content: str


class OAIRequest(BaseModel):
    model: str = "rs-gpt"
    messages: list[OAIMessage]
    max_tokens: int = 400
    temperature: float = 0.8


@app.post("/v1/chat/completions")
def openai_chat(req: OAIRequest):
    user_msgs = [m.content for m in req.messages if m.role == "user"]
    message = user_msgs[-1] if user_msgs else ""
    reply, provider = smart_reply(message, req.max_tokens, req.temperature)
    return {
        "id": f"chatcmpl-{int(time.time())}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": req.model,
        "provider": provider,
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": reply},
            "finish_reason": "stop",
        }],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }


CHAT_HTML = """<!DOCTYPE html>
<html lang="si">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<title>RS AI — සිංහල AI Chat</title>
<style>
  * { box-sizing: border-box; margin: 0; }
  body {
    font-family: 'Segoe UI', 'Noto Sans Sinhala', system-ui, sans-serif;
    background: linear-gradient(160deg, #0f172a 0%, #1e1b4b 100%);
    color: #e2e8f0; height: 100dvh; display: flex; flex-direction: column;
  }
  header {
    padding: 14px 18px; display: flex; align-items: center; gap: 12px;
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
  #chat { flex: 1; overflow-y: auto; padding: 18px; display: flex; flex-direction: column; gap: 12px; }
  .msg { max-width: 82%; padding: 11px 15px; border-radius: 18px; line-height: 1.55;
         font-size: 15px; white-space: pre-wrap; word-wrap: break-word; animation: pop .25s ease; }
  @keyframes pop { from { opacity:0; transform: translateY(6px);} to { opacity:1; } }
  .user { align-self: flex-end; background: linear-gradient(135deg,#7c3aed,#4f46e5);
          color: white; border-bottom-right-radius: 5px; }
  .bot  { align-self: flex-start; background: #1e293b; border: 1px solid rgba(148,163,184,.12);
          border-bottom-left-radius: 5px; }
  .chiprow { display:flex; gap:8px; flex-wrap:wrap; padding: 0 18px 8px; }
  .chip { background:#1e293b; border:1px solid rgba(148,163,184,.25); color:#c4b5fd;
          padding:7px 13px; border-radius: 999px; font-size:13px; cursor:pointer; }
  .chip:hover { background:#312e81; }
  footer { padding: 12px 14px; background: rgba(15,23,42,.9); border-top: 1px solid rgba(148,163,184,.15);
           display: flex; gap: 10px; }
  input {
    flex: 1; background: #1e293b; border: 1px solid rgba(148,163,184,.25); border-radius: 999px;
    padding: 13px 18px; color: #e2e8f0; font-size: 15px; outline: none;
  }
  input:focus { border-color: #7c3aed; }
  button {
    background: linear-gradient(135deg,#7c3aed,#4f46e5); border: none; color: white;
    width: 48px; height: 48px; border-radius: 50%; font-size: 19px; cursor: pointer;
  }
  button:disabled { opacity: .5; }
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
    <div class="sub"><span class="dot" id="dot"></span><span id="subtxt">සබැඳිවෙමින්…</span></div>
  </div>
</header>
<div id="chat">
  <div class="msg bot">ආයුබෝවන්! මම <b>RS AI</b> — සිංහල සහ ඉංග්‍රීසි කතා කරන AI සහායකයෙක්. ප්‍රශ්නයක් අහන්න! 👋</div>
</div>
<div class="chiprow">
  <div class="chip" onclick="ask('ඔයා කවුද?')">ඔයා කවුද?</div>
  <div class="chip" onclick="ask('සීගිරිය ගැන කියන්න')">සීගිරිය 🏰</div>
  <div class="chip" onclick="ask('AI කියන්නේ මොකක්ද?')">AI කියන්නේ මොකක්ද?</div>
  <div class="chip" onclick="ask('what can you do?')">What can you do?</div>
</div>
<footer>
  <input id="inp" placeholder="මෙසේජ් එකක් ලියන්න…" autocomplete="off">
  <button id="send" onclick="send()">➤</button>
</footer>
<script>
const chat = document.getElementById('chat');
const inp = document.getElementById('inp');
const btn = document.getElementById('send');
inp.addEventListener('keydown', e => { if (e.key === 'Enter') send(); });

fetch('/health').then(r => r.json()).then(h => {
  const el = document.getElementById('subtxt');
  if (h.active && h.active !== 'rs-gpt-local') {
    el.textContent = '⚡ smart mode · ' + h.active + ' · Sinhala + English';
  } else {
    el.textContent = 'සබැඳි · Sinhala + English · RS-GPT local';
  }
}).catch(() => { document.getElementById('subtxt').textContent = 'සබැඳි'; });

function add(text, cls) {
  const d = document.createElement('div');
  d.className = 'msg ' + cls;
  d.textContent = text;
  chat.appendChild(d);
  chat.scrollTop = chat.scrollHeight;
  return d;
}
function ask(q) { inp.value = q; send(); }
async function send() {
  const text = inp.value.trim();
  if (!text) return;
  inp.value = '';
  add(text, 'user');
  btn.disabled = true;
  const t = document.createElement('div');
  t.className = 'msg bot typing';
  t.innerHTML = '<span></span><span></span><span></span>';
  chat.appendChild(t);
  chat.scrollTop = chat.scrollHeight;
  try {
    const r = await fetch('/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: text })
    });
    const j = await r.json();
    t.remove();
    add(j.reply || '…', 'bot');
  } catch (e) {
    t.remove();
    add('⚠️ දෝෂයක් — server එක බලන්න / Error: ' + e.message, 'bot');
  }
  btn.disabled = false;
  inp.focus();
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
