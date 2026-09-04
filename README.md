# RS AI — සිංහල/English 1B LLM + Android App 🤖

සිංහල සහ ඉංග්‍රීසි කතා කරන **තමන්ගේම AI model එකක්** (1B parameters දක්වා) —
training pipeline එක, inference server එක, සහ Android chat app එක එකතුව.

Your own Sinhala + English AI model (up to ~1B params) — training pipeline,
FastAPI inference server, and an Android chat app, all in one repo.

## 🗂️ Project Structure

```
Rs-et/
├── model/                  # RS-GPT — language model + training code
│   ├── gpt.py              #   Transformer (RMSNorm, RoPE, SwiGLU, ~1B config)
│   ├── config.py           #   Model sizes: rs-gpt-1b / 1.2b / 60m / demo
│   ├── tokenizer_train.py  #   SentencePiece BPE tokenizer (Sinhala-safe)
│   ├── train.py            #   Training loop (AMP, cosine LR, checkpoints)
│   ├── generate.py         #   CLI generation
│   ├── data/sample_corpus.txt
│   └── README.md           #   📖 සිංහල 1B training guide (GPU steps)
│
├── server/
│   └── main.py             # FastAPI server: /chat + /v1/chat/completions + web UI
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

# 3. Android app එක → android-app/BUILD_GUIDE.md බලන්න
```

## 📱 App Preview

Dark Material 3 chat UI — Sinhala placeholder text, suggestion chips,
typing indicator, server URL settings dialog. Server එකේ web UI එකත්
එම design එකම use කරනවා.

## 🧠 Real 1B Training

සැබෑ 1B model එකක් train කරන්න GPU එකක් ඕන (A100 එකකදී දවස් ~10-12).
සම්පූර්ණ Sinhala guide එක: [`model/README.md`](model/README.md)
— data sources (CulturaX `si`, CC-100), tokenizer, commands ඔක්කොම තියෙනවා.

---

Made with ❤️ for Sinhala AI — by RS team.
