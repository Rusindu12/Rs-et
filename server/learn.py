"""
RS AI — teach & fine-tune module.

Two levels of "training" from the app/web UI:

1. 📚 MEMORY (instant): user-written facts (Q&A, rules, about them) stored in
   model/data/rs_memory.json and injected into every prompt/system message.
   Works immediately — external providers and the local model alike.

2. 🧠 FINE-TUNE (bakes in): a background thread continues training the loaded
   RS-GPT on model/data/custom_corpus.txt (+ sample corpus), then hot-saves the
   checkpoint — the running server immediately talks with the new brain.
   Intended for the small demo configs on CPU/Colab (steps are capped).
"""

import json
import os
import random
import threading
import time
from pathlib import Path

import torch
import torch.nn.functional as F

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "model" / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)
MEM_FILE = DATA_DIR / "rs_memory.json"
CORPUS_FILE = DATA_DIR / "custom_corpus.txt"

CORPUS_CAP = int(os.environ.get("RS_CORPUS_CAP", "200000"))     # chars
MAX_STEPS = int(os.environ.get("RS_MAX_TRAIN_STEPS", "400"))    # safety cap


# --------------------------------------------------------------------------- #
# 1) Memory facts
# --------------------------------------------------------------------------- #

def memory_list() -> list[str]:
    if not MEM_FILE.exists():
        return []
    try:
        data = json.loads(MEM_FILE.read_text(encoding="utf-8"))
        return [str(x) for x in data if str(x).strip()]
    except Exception:
        return []


def _save_memory(items: list[str]):
    MEM_FILE.write_text(json.dumps(items[-80:], ensure_ascii=False, indent=1),
                        encoding="utf-8")


def memory_add(text: str) -> list[str]:
    items = memory_list()
    t = text.strip()
    if t:
        items.append(t[:800])
        _save_memory(items)
    return items


def memory_delete(idx: int) -> list[str]:
    items = memory_list()
    if 0 <= idx < len(items):
        items.pop(idx)
        _save_memory(items)
    return items


def knowledge_block() -> str:
    """Text injected into prompts: formatted user facts (capped)."""
    items = memory_list()
    if not items:
        return ""
    lines = "\n".join(f"- {x}" for x in items[-30:])
    block = (f"Important things the user taught RS AI:\n{lines}\n")
    return block[:1200]


# --------------------------------------------------------------------------- #
# 2) Corpus + fine-tune
# --------------------------------------------------------------------------- #

def corpus_size() -> int:
    return CORPUS_FILE.stat().st_size if CORPUS_FILE.exists() else 0


def corpus_add(text: str) -> dict:
    t = (text or "").strip()
    if not t:
        return {"ok": False, "error": "empty text", "corpus_chars": corpus_size()}
    cur = corpus_size()
    if cur + len(t) > CORPUS_CAP:
        return {"ok": False,
                "error": f"corpus full ({CORPUS_CAP} chars cap — clear or restart)",
                "corpus_chars": cur}
    with open(CORPUS_FILE, "a", encoding="utf-8") as f:
        if cur:
            f.write("\n")
        f.write(t)
    return {"ok": True, "corpus_chars": corpus_size()}


_state = {
    "running": False, "step": 0, "total": 0, "loss": None,
    "started_at": None, "finished_at": None, "error": None, "last_run": None,
}


def train_status() -> dict:
    return dict(_state)


def _as_chat_format(raw: str) -> str:
    """Wrap raw teaching text into the RS chat-template if it isn't already."""
    if "<|user|>" in raw or "<|assistant|>" in raw:
        return raw
    # Split on blank lines: odd = question, even = answer (best effort)
    parts = [p.strip() for p in raw.split("\n") if p.strip()]
    out = []
    for i in range(0, len(parts) - 1, 2):
        out.append(f"<|user|>\n{parts[i]}\n<|assistant|>\n{parts[i+1]}\n<|end|>")
    if len(parts) % 2 == 1:
        out.append(f"<|user|>\nQuestion about this:\n<|assistant|>\n{parts[-1]}\n<|end|>")
    return "\n".join(out) if out else raw


def run_training(model, sp, cfg, ckpt_path: str, steps: int = 150, lr: float = 3e-4,
                 device: str = "cpu", include_memory: bool = True) -> dict:
    """Fine-tune in a background thread; model weights update live in RAM."""
    if _state["running"]:
        return {"ok": False, "error": "training already running"}
    steps = max(10, min(int(steps), MAX_STEPS))

    def _worker():
        _state.update({"running": True, "step": 0, "total": steps, "loss": None,
                       "started_at": time.time(), "finished_at": None, "error": None,
                       "last_run": None})
        try:
            text_parts = []
            base = DATA_DIR / "sample_corpus.txt"
            if base.exists():
                text_parts.append(base.read_text(encoding="utf-8")[:20000])
            if CORPUS_FILE.exists():
                text_parts.append(_as_chat_format(CORPUS_FILE.read_text(encoding="utf-8")))
            if include_memory:
                raw_mem = "\n".join(memory_list())
                if raw_mem:
                    text_parts.append(_as_chat_format(raw_mem))
            if not any(x.strip() for x in text_parts):
                raise RuntimeError("no corpus text — add teaching text first")
            ids = torch.tensor(sp.encode("\n".join(text_parts)), dtype=torch.long)
            if ids.numel() < cfg.block_size + 2:
                raise RuntimeError("corpus too small for context window")

            model.train()
            opt = torch.optim.AdamW(model.parameters(), lr=lr)
            dev = torch.device(device)
            for step in range(steps):
                ix = torch.randint(0, ids.numel() - cfg.block_size - 1,
                                   (4,), device=dev)
                x = torch.stack([ids[i:i + cfg.block_size] for i in ix]).to(dev)
                y = torch.stack([ids[i + 1:i + cfg.block_size + 1] for i in ix]).to(dev)
                logits, _ = model(x)
                loss = F.cross_entropy(
                    logits.view(-1, cfg.vocab_size) / 1.0, y.view(-1), ignore_index=-1)
                opt.zero_grad(set_to_none=True)
                loss.backward()
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                opt.step()
                _state["step"] = step + 1
                _state["loss"] = float(loss.item())
            model.eval()
            # hot-save the new brain next to the live checkpoint
            try:
                backup = ckpt_path + ".bak"
                if not os.path.exists(backup) and os.path.exists(ckpt_path):
                    import shutil
                    shutil.copy2(ckpt_path, backup)
            except Exception:
                pass
            torch.save({
                "model": {k: v.cpu() for k, v in model.state_dict().items()},
                "config": vars(cfg) if not isinstance(cfg, dict) else cfg,
                "tokenizer": None,
            }, ckpt_path[:-3] + "_ft.pt" if ckpt_path.endswith(".pt") else ckpt_path + "_ft")
            model.to(dev)
            _state["last_run"] = {"steps": steps, "final_loss": _state["loss"]}
        except Exception as e:  # noqa: BLE001
            _state["error"] = repr(e)
            try:
                model.eval()
            except Exception:
                pass
        finally:
            _state["running"] = False
            _state["finished_at"] = time.time()

    threading.Thread(target=_worker, daemon=True).start()
    return {"ok": True, "steps": steps, "lr": lr,
            "note": "fine-tune running in background — GET /train/status"}
