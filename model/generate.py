"""Generate text from a trained RS-GPT checkpoint.

Usage:
    python generate.py --ckpt runs/demo/ckpt.pt \
        --prompt "<|user|>\nඔයා කවුද?\n<|assistant|>\n"
"""

import argparse

import torch
import sentencepiece as spm

from gpt import GPT, GPTConfig


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", required=True)
    ap.add_argument("--tokenizer", default=None, help="SentencePiece .model (default: from ckpt)")
    ap.add_argument("--prompt", default="<|user|>\nඔයා කවුද?\n<|assistant|>\n")
    ap.add_argument("--max-tokens", type=int, default=150)
    ap.add_argument("--temperature", type=float, default=0.8)
    ap.add_argument("--top-k", type=int, default=50)
    ap.add_argument("--top-p", type=float, default=0.9)
    ap.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    args = ap.parse_args()

    ckpt = torch.load(args.ckpt, map_location=args.device)
    cfg = GPTConfig(**ckpt["config"])
    model = GPT(cfg)
    model.load_state_dict(ckpt["model"])
    model.to(args.device).eval()
    print(f"[model] loaded {args.ckpt} — {model.num_params():,} params")

    sp_path = args.tokenizer or ckpt.get("tokenizer")
    sp = spm.SentencePieceProcessor(model_file=sp_path)

    ids = sp.encode(args.prompt)
    idx = torch.tensor(ids, dtype=torch.long, device=args.device)[None, :]
    eos = sp.piece_to_id("<|end|>")
    out = model.generate(idx, max_new_tokens=args.max_tokens,
                         temperature=args.temperature, top_k=args.top_k,
                         top_p=args.top_p, eos_id=eos)
    print("---")
    print(sp.decode(out[0].tolist()))


if __name__ == "__main__":
    main()
