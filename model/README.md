# RS-GPT — සිංහල/English Language Models (3.6M → 4B params)

සිංහල සහ ඉංග්‍රීසි කතා කරන, **0 ඉඳන්ම තමාගේන්ම** train කරන GPT-style
decoder-only transformer design එකක්. Configs: demo 3.6M ඉඳන් flagship
**~3.95B ("4B")** දක්වා.

A from-scratch Sinhala + English GPT-style transformer, with configs from a
3.6M CPU demo up to a ~3.95B-parameter flagship ("rs-gpt-4b").

## ගෘහනිර්මාණය (Architecture)

| Feature | RS-GPT |
|---|---|
| Type | Decoder-only Transformer |
| Normalization | RMSNorm (pre-norm) |
| Position | RoPE (Rotary Position Embeddings) |
| MLP | SwiGLU |
| Attention | Causal MHA via FlashAttention (SDPA) |
| Embeddings | Tied input/output |
| Tokenizer | SentencePiece BPE, `byte_fallback` (Sinhala-safe) |

## Configs

| Config | Params | Layers | d_model | Heads | Context | Purpose |
|---|---|---|---|---|---|---|
| `rs-gpt-4b` | **~3.95B** | 34 | 3072 | 24 | 2048 | 🏆 Flagship 4B |
| `rs-gpt-1b` | ~0.98B | 18 | 2048 | 16 | 2048 | The 1B flagship |
| `rs-gpt-1.2b` | ~1.08B | 20 | 2048 | 16 | 2048 | Bigger 1B variant |
| `rs-gpt-60m` | ~42M | 8 | 512 | 8 | 1024 | Single-GPU experiments |
| `rs-gpt-demo` | ~3.6M | 4 | 256 | 4 | 128 | CPU demo / pipeline test |

## Hardware guide (training)

| Config | Optimizer | Suggested GPU | Notes |
|---|---|---|---|
| demo | adamw | CPU only | විනාඩි ~5 |
| 60m | adamw | T4 16GB (Colab free) | overnight run = decent small model |
| 1b | adamw | A100-40GB | bf16 + grad-accum |
| **4b** | **adamw8bit + --grad-checkpoint** | **A100-40GB possible*, H100/A100-80GB හොඳම** | *batch 4-8 + accum |

4B training memory breakdown (bf16, grad-checkpoint, adamw8bit):
weights ~8GB + grads ~8GB + optimizer ~8GB + activations ~6-12GB ≈ **30-40GB** →
A100-40GB එකකට ඉඩ තියෙනවා. Chinchilla tokens for 4B ≈ **80B tokens** —
single A100-40GB එකකදී සති ගණනක්; H100 8× multi-GPU (DDP roadmap) දවස් ගණන.
පටන් ගැනීමට: 4B + tokens 2-4B (under-trained නමුත් usable) = දවස් 2-4 @ A100.

## Quick start (demo — CPU වලින් වුණත් වැඩ කරයි)

```bash
cd model
pip install -r requirements.txt

# 1) Tokenizer train කරන්න
python tokenizer_train.py --input data/sample_corpus.txt \
    --vocab-size 1600 --model-prefix tokenizer/rs_sp

# 2) Model train කරන්න (CPU: මිනිත්තු ~5)
python train.py --config rs-gpt-demo --data data/sample_corpus.txt \
    --tokenizer tokenizer/rs_sp.model --out-dir runs/demo \
    --steps 450 --batch-size 16

# 3) Generate කරන්න
python generate.py --ckpt runs/demo/ckpt.pt \
    --prompt "<|user|>\nඔයා කවුද?\n<|assistant|>\n"
```

## සැබෑ 1B training (GPU ඕන) — Real 1B training

**Honest numbers:** 1B ආකෘතියක් *හොඳට* train කරන්න Chinchilla scaling අනුව
~20B tokens ක් පමණ ඕන වෙනවා. A100-40GB GPU එකකදී මේ pipeline එක ~20-25k tok/s
කට පමණ වැඩ කරනවා (bf16) → 20B tokens ≈ **දවස් 10-12** (multi-GPU නම් ඊට අඩුයි).
ආරම්භයකට `rs-gpt-60m` + Colab T4 එකක් ප්‍රමාණවත්.

### පියවර 1 — Data එකතු කිරීම (Sinhala corpus)

Sinhala training data sources:

```python
from datasets import load_dataset

# විකල්ප sources:
# 1) CulturaX (Sinhala subset) — විශාලම සහ පිරිසිදුම
ds = load_dataset("uonlp/CulturaX", "si", split="train")
# 2) CC-100 Sinhala
ds = load_dataset("cc100", "si", split="train")
# 3) OSCAR Sinhala, Sinhala Wikipedia, MADLAD-400 si...

# සියල්ල එක්ක කරලා එකක් text file එකකට:
with open("data/corpus_si.txt", "w", encoding="utf-8") as f:
    for row in ds:
        f.write(row["text"].strip() + "\n\n")
```

English සඳහා `openwebtext`, `HuggingFaceFW/fineweb-edu` වැනි ඒවා mix කරන්න.
ඉලක්කය: **tokens බිලියන 2-5 ක්වත්** (text ~10-20 GB).

### පියවර 2 — 32k Tokenizer

```bash
python tokenizer_train.py --input data/corpus_all.txt \
    --vocab-size 32000 --model-prefix tokenizer/rs_sp_32k
```

### පියවර 3 — Pre-tokenize to .npy

```python
import numpy as np, sentencepiece as spm
sp = spm.SentencePieceProcessor(model_file="tokenizer/rs_sp_32k.model")
ids = []
with open("data/corpus_all.txt", encoding="utf-8") as f:
    for line in f:
        ids.extend(sp.encode(line.strip()))
np.save("data/tokens_32k.npy", np.array(ids, dtype=np.uint32))
```

### පියවර 4 — Train (A100/H100)

```bash
python train.py --config rs-gpt-1b \
    --data data/tokens_32k.npy \
    --tokenizer tokenizer/rs_sp_32k.model \
    --out-dir runs/rs-gpt-1b \
    --steps 20000 --batch-size 32 --grad-accum 16 \
    --lr 3e-4 --min-lr 3e-5 --warmup 500 \
    --log-interval 20 --eval-interval 500 --sample-every 1000 --save-every 1000
```

* tokens/step = 32 × 16 × 2048 ≈ 1.05M → 20k steps ≈ 21B tokens ✅
* VRAM: 1B model bf16 + AdamW ≈ ~18-22 GB → A100-40GB/80GB හරි යයි.
* Multi-GPU: code එක single-GPU සරලයි — DDP version එක roadmap එකේ.

### 4B training (flagship)

```bash
pip install bitsandbytes   # 8-bit optimizer සඳහා

python train.py --config rs-gpt-4b \
    --data data/tokens_32k.npy \
    --tokenizer tokenizer/rs_sp_32k.model \
    --out-dir runs/rs-gpt-4b \
    --optim adamw8bit --grad-checkpoint \
    --steps 38000 --batch-size 8 --grad-accum 64 \
    --lr 2e-4 --min-lr 2e-5 --warmup 800 \
    --log-interval 10 --eval-interval 500 --sample-every 2000 --save-every 1000
```

* tokens/step = 8 × 64 × 2048 ≈ 1.05M → 38k steps ≈ 40B tokens (Chinchilla-lite for 4B)
* Inference: bf16 ~7.9GB (A100/RTX 4090 OK), Q4 GGUF නම් ~2.3GB → phone එකකටත්! (GGUF export = roadmap)
* Server එකට දාන්න: `RS_CKPT=runs/rs-gpt-4b/ckpt.pt python server/main.py`

### පියවර 5 — Chat fine-tuning (optional)

Pretrain වලින් පස්සේ `<|user|>/<|assistant|>/<|end|>` format එකේ
Q&A දත්ත සමඟ කුඩා corpa එකකින් පාර් minutesක් fine-tune කරන්න:

```bash
python train.py --config rs-gpt-1b --data data/chat_si.txt \
    --tokenizer tokenizer/rs_sp_32k.model \
    --resume runs/rs-gpt-1b/ckpt.pt \
    --out-dir runs/rs-gpt-1b-chat \
    --steps 500 --batch-size 8 --lr 1e-4
```

## Files

```
model/
├── gpt.py               # Transformer model (RMSNorm, RoPE, SwiGLU)
├── config.py            # Model size configs (1B → demo)
├── tokenizer_train.py   # SentencePiece tokenizer trainer
├── train.py             # Training loop (AMP, cosine LR, checkpoints)
├── generate.py          # Interactive/CLI generation
├── data/sample_corpus.txt  # Sinhala+English demo corpus
└── runs/                # Checkpoints land here (git-ignored)
```

## Roadmap

- [x] 8-bit optimizer (`--optim adamw8bit`) — 4B training on A100-40GB
- [x] Gradient checkpointing (`--grad-checkpoint`)
- [ ] DDP multi-GPU training (4B Chinchilla-scale සඳහා අවශ්‍යයි)
- [ ] GGUF export (llama.cpp) → phone එකේ on-device run
- [ ] Eval harness (Sinhala benchmarks)
- [ ] Streaming generation in server
