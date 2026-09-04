"""
Train RS-GPT on a text corpus.

Quick demo (CPU):
    python tokenizer_train.py --input data/sample_corpus.txt \
        --vocab-size 1600 --model-prefix tokenizer/rs_sp
    python train.py --config rs-gpt-demo --data data/sample_corpus.txt \
        --tokenizer tokenizer/rs_sp.model --out-dir runs/demo \
        --steps 400 --batch-size 16 --block-size 128

Real 1B training (GPU) — see README.md.
"""

import argparse
import json
import math
import os
import time
from dataclasses import asdict, replace

import numpy as np
import torch
import sentencepiece as spm

from gpt import GPT
from config import CONFIGS


# --------------------------------------------------------------------------- #
# Data
# --------------------------------------------------------------------------- #

def load_tokens(data_path: str, sp: spm.SentencePieceProcessor = None) -> np.ndarray:
    """Load a pre-tokenized .npy file, or tokenize raw text with SentencePiece."""
    if data_path.endswith(".npy"):
        return np.load(data_path, mmap_mode="r")
    assert sp is not None, "tokenizer required for raw text data"
    with open(data_path, "r", encoding="utf-8") as f:
        text = f.read()
    ids = sp.encode(text)
    print(f"[data] tokenized {len(text):,} chars -> {len(ids):,} tokens")
    return np.array(ids, dtype=np.uint16)


def get_batch(data, block_size: int, batch_size: int, device: str, gen: torch.Generator):
    ix = torch.randint(len(data) - block_size - 1, (batch_size,), generator=gen)
    x = torch.stack([torch.from_numpy(np.asarray(data[i:i + block_size], dtype=np.int64)) for i in ix])
    y = torch.stack([torch.from_numpy(np.asarray(data[i + 1:i + 1 + block_size], dtype=np.int64)) for i in ix])
    return x.to(device), y.to(device)


# --------------------------------------------------------------------------- #
# LR schedule: linear warmup + cosine decay
# --------------------------------------------------------------------------- #

def get_lr(step, warmup_steps, max_steps, max_lr, min_lr):
    if step < warmup_steps:
        return max_lr * (step + 1) / max(1, warmup_steps)
    if step >= max_steps:
        return min_lr
    ratio = (step - warmup_steps) / max(1, max_steps - warmup_steps)
    coeff = 0.5 * (1.0 + math.cos(math.pi * ratio))
    return min_lr + coeff * (max_lr - min_lr)


def configure_optimizer(model: GPT, lr: float, weight_decay: float):
    """AdamW with weight decay only on >=2D weights (matrices), nanoGPT style."""
    decay, no_decay = [], []
    for _, p in model.named_parameters():
        (decay if p.dim() >= 2 else no_decay).append(p)
    groups = [
        {"params": decay, "weight_decay": weight_decay},
        {"params": no_decay, "weight_decay": 0.0},
    ]
    return torch.optim.AdamW(groups, lr=lr, betas=(0.9, 0.95), eps=1e-8, fused=torch.cuda.is_available())


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="rs-gpt-demo", choices=list(CONFIGS.keys()))
    ap.add_argument("--data", required=True, help="raw text file or pre-tokenized .npy")
    ap.add_argument("--tokenizer", default=None, help="SentencePiece .model (required for raw text)")
    ap.add_argument("--out-dir", default="runs/run")
    ap.add_argument("--steps", type=int, default=1000)
    ap.add_argument("--batch-size", type=int, default=16)
    ap.add_argument("--grad-accum", type=int, default=1)
    ap.add_argument("--block-size", type=int, default=0, help="0 = use model config")
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--min-lr", type=float, default=1e-4)
    ap.add_argument("--warmup", type=int, default=50)
    ap.add_argument("--weight-decay", type=float, default=0.1)
    ap.add_argument("--grad-clip", type=float, default=1.0)
    ap.add_argument("--log-interval", type=int, default=10)
    ap.add_argument("--eval-interval", type=int, default=100)
    ap.add_argument("--sample-every", type=int, default=100)
    ap.add_argument("--sample-prompt", default="<|user|>\nඔයාට කොහොමද?\n<|assistant|>\n")
    ap.add_argument("--save-every", type=int, default=200)
    ap.add_argument("--resume", default=None, help="checkpoint .pt to resume from")
    ap.add_argument("--seed", type=int, default=1337)
    args = ap.parse_args()

    torch.manual_seed(args.seed)
    gen = torch.Generator().manual_seed(args.seed)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    os.makedirs(args.out_dir, exist_ok=True)

    # ---- config & data ----
    cfg = CONFIGS[args.config]
    if args.block_size > 0:
        cfg = replace(cfg, block_size=args.block_size)

    sp = None
    if args.tokenizer:
        sp = spm.SentencePieceProcessor(model_file=args.tokenizer)
        cfg = replace(cfg, vocab_size=max(cfg.vocab_size, sp.vocab_size()))

    tokens = load_tokens(args.data, sp)
    n_val = max(int(0.02 * len(tokens)), cfg.block_size + 2)
    if len(tokens) < 2 * n_val:
        # tiny dataset: not enough for a real split — validate on train data
        train_data, val_data = tokens, tokens
    else:
        train_data, val_data = tokens[:-n_val], tokens[-n_val:]
    print(f"[data] train={len(train_data):,}  val={len(val_data):,} tokens")

    # ---- model ----
    model = GPT(cfg).to(device)
    print(f"[model] {args.config}: {model.num_params():,} params "
          f"({model.num_params()/1e6:.1f}M), device={device}")
    if args.resume:
        ckpt = torch.load(args.resume, map_location=device)
        model.load_state_dict(ckpt["model"])
        print(f"[resume] loaded {args.resume} @ step {ckpt.get('step')}")

    opt = configure_optimizer(model, args.lr, args.weight_decay)

    use_amp = device == "cuda"
    amp_dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float16
    scaler = torch.amp.GradScaler("cuda", enabled=(use_amp and amp_dtype == torch.float16))

    def estimate_val_loss():
        model.eval()
        losses = []
        for _ in range(10):
            x, y = get_batch(val_data, cfg.block_size, args.batch_size, device, gen)
            with torch.autocast(device, dtype=amp_dtype, enabled=use_amp):
                _, loss = model(x, y)
            losses.append(loss.item())
        model.train()
        return float(np.mean(losses))

    def save_ckpt(step):
        path = os.path.join(args.out_dir, "ckpt.pt")
        torch.save({
            "model": model.state_dict(),
            "config": asdict(cfg),
            "config_name": args.config,
            "step": step,
            "tokenizer": os.path.abspath(args.tokenizer) if args.tokenizer else None,
        }, path)
        print(f"[save] {path} @ step {step}")

    def sample(step):
        if sp is None:
            return
        model.eval()
        ids = sp.encode(args.sample_prompt)
        idx = torch.tensor(ids, dtype=torch.long, device=device)[None, :]
        out = model.generate(idx, max_new_tokens=80, temperature=0.7, top_k=40, top_p=0.9)
        text = sp.decode(out[0].tolist())
        print(f"\n--- sample @ step {step} ---\n{text}\n-----------------------")
        model.train()

    # ---- training loop ----
    print("[train] starting...")
    t0 = time.time()
    for step in range(args.steps):
        lr = get_lr(step, args.warmup, args.steps, args.lr, args.min_lr)
        for g in opt.param_groups:
            g["lr"] = lr

        loss_accum = 0.0
        for _ in range(args.grad_accum):
            x, y = get_batch(train_data, cfg.block_size, args.batch_size, device, gen)
            with torch.autocast(device, dtype=amp_dtype, enabled=use_amp):
                _, loss = model(x, y)
                loss = loss / args.grad_accum
            scaler.scale(loss).backward()
            loss_accum += loss.item()

        if args.grad_clip > 0:
            scaler.unscale_(opt)
            torch.nn.utils.clip_grad_norm_(model.parameters(), args.grad_clip)
        scaler.step(opt)
        scaler.update()
        opt.zero_grad(set_to_none=True)

        if step % args.log_interval == 0:
            dt = time.time() - t0
            tps = (step + 1) * args.batch_size * args.grad_accum * cfg.block_size / max(dt, 1e-9)
            print(f"step {step:5d}/{args.steps} | loss {loss_accum:.4f} | lr {lr:.2e} "
                  f"| {tps:,.0f} tok/s | {dt:.0f}s")

        if (step + 1) % args.eval_interval == 0:
            print(f"step {step+1}: val loss {estimate_val_loss():.4f}")
        if (step + 1) % args.sample_every == 0 and sample(step) is None:
            pass
        if (step + 1) % args.save_every == 0:
            save_ckpt(step + 1)

    save_ckpt(args.steps)
    sample(args.steps)
    print(f"[done] total time {time.time() - t0:.0f}s")
    with open(os.path.join(args.out_dir, "train_args.json"), "w") as f:
        json.dump(vars(args), f, indent=2)


if __name__ == "__main__":
    main()
