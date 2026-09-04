# RS AI — සිංහල/English LLM (up to 4B) + Android App 🤖

සිංහල සහ ඉංග්‍රීසි කතා කරන **තමන්ගේම AI model එකක්** (3.6M → **~3.95B "4B"** configs) —
training pipeline එක, inference server එක, සහ Android chat app එක එකතුව.

Your own Sinhala + English AI model (configs from a 3.6M CPU demo up to a
~3.95B-parameter "rs-gpt-4b" flagship) — training pipeline, FastAPI inference
server, and an Android chat app, all in one repo.

## 🗂️ Project Structure

```
Rs-et/
├── model/                  # RS-GPT — language model + training code
│   ├── gpt.py              #   Transformer (RMSNorm, RoPE, SwiGLU, ~1B config)
│   ├── config.py           #   Model sizes: rs-gpt-4b / 1b / 1.2b / 60m / demo
│   ├── tokenizer_train.py  #   SentencePiece BPE tokenizer (Sinhala-safe)
│   ├── train.py            #   Training loop (AMP, cosine LR, checkpoints)
│   ├── generate.py         #   CLI generation
│   ├── data/sample_corpus.txt
│   └── README.md           #   📖 සිංහල 1B training guide (GPU steps)
│
├── server/
│   ├── main.py             # FastAPI: /chat + /v1/chat/completions + web UI + PWA
│   ├── providers.py        # 🔀 smart routing: Groq/OpenAI/Gemini/custom + local fallback
│   ├── static/             #   PWA: manifest, service worker, icons
│   └── README.md           #   📖 API key setup guide (නොමිලේ keys)
├── docs/ACCESS.md          # 🌍 deploy anywhere + PWA + API token guide
├── Dockerfile              # 🐳 one-image deploy (HF Spaces / Render / VPS)
│
└── android-app/            # RS AI Chat — Kotlin + Jetpack Compose app
    ├── app/src/main/java/com/ruset/ai/
    └── BUILD_GUIDE.md      # 📖 APK හදන ආකාරය (Android Studio, 5 min)
```

## 🚀 Quick Start

```bash
pip install torch sentencepiece fastapi "uvicorn[standard]" numpy

# 1. Tokenizer + demo model train කරන්න (CPU, විනාඩි ~5)
cd model && mkdir -p tokenizer runs
python tokenizer_train.py --input data/sample_corpus.txt \
    --vocab-size 1600 --model-prefix tokenizer/rs_sp
python train.py --config rs-gpt-demo --data data/sample_corpus.txt \
    --tokenizer tokenizer/rs_sp.model --out-dir runs/demo --steps 450

# 2. Server එක run කරන්න → http://localhost:8000 (web chat UI එකත් එන්නේ මෙතනින්)
cd .. && python server/main.py

# 2b. (optional) වෙනත් AI වලින් උත්තර අරන් RS AI විදියට දෙන්න — smart mode ⚡
#     Groq free key එකක්: https://console.groq.com ඉඳන්
RS_PROVIDER=groq RS_API_KEY=gsk_... python server/main.py

# 3. Android app එක → android-app/BUILD_GUIDE.md බලන්න
```

## 📱 App Preview

Dark Material 3 chat UI — Sinhala placeholder text, suggestion chips,
typing indicator, server URL settings dialog. Server එකේ web UI එකත්
එම design එකම use කරනවා.

## 🌍 Access from Anywhere

RS AI server එක public කරලා **ඕනම device එකකින්** use කරන්න පුළුවන්:
* 🐳 **Dockerfile** — Hugging Face Spaces / Render / Railway / VPS
* 📱 **PWA** — browser එකෙන් "Add to Home Screen" (APK නැතුවත් app වගේ)
* 🔑 **RS_API_TOKEN** — public server protect කිරීම
* 🔌 **OpenAI-compatible API** — ඕනම client/SDK/app එකෙන්

📖 සම්පූර්ණ guide: **[docs/ACCESS.md](docs/ACCESS.md)**

## 🧠 Real Training (1B / 4B)

සැබෑ large models train කරන්න GPU එකක් ඕන:
* **rs-gpt-1b** (0.98B) — A100-40GB, දවස් ~10-12 (20B tokens)
* **rs-gpt-4b** (3.95B) — `--optim adamw8bit --grad-checkpoint` සමඟ A100-40GB
  එකකින් වුණත් ප්‍රචණ්ඩ කාලයකදී; H100/80GB හොඳම (40B tokens ≈ Chinchilla-lite)

සම්පූර්ණ Sinhala guide එක: [`model/README.md`](model/README.md)
— data sources (CulturaX `si`, CC-100), tokenizer, commands ඔක්කොම තියෙනවා.
Train කරපු ckpt එක server එකට දාන්න:
`RS_CKPT=model/runs/rs-gpt-4b/ckpt.pt python server/main.py`

---

Made with ❤️ for Sinhala AI — by RS team.
