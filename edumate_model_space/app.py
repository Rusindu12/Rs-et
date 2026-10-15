"""Optional Hugging Face Space model server for EduMate.

Exposes the OpenAI-compatible endpoint consumed by edumate_backend. Model
weights are downloaded at Space startup and are not stored in this repository.
"""

from __future__ import annotations

import os
import secrets
import threading
import time
import uuid
from typing import Any

import torch
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from transformers import AutoModelForCausalLM, AutoTokenizer

MODEL_ID = os.getenv("MODEL_ID", "meta-llama/Llama-3.2-3B-Instruct")
HF_TOKEN = os.getenv("HF_TOKEN") or None
INFERENCE_BEARER_TOKEN = os.getenv("INFERENCE_BEARER_TOKEN", "").strip()

app = FastAPI(title="EduMate self-hosted LLM", version="0.1.0")
model_lock = threading.Lock()
tokenizer = None
model = None


class Message(BaseModel):
    role: str = Field(pattern="^(system|user|assistant)$")
    content: str = Field(max_length=12000)


class ChatCompletionRequest(BaseModel):
    model: str | None = None
    messages: list[Message] = Field(min_length=1, max_length=24)
    temperature: float = Field(default=0.35, ge=0, le=1.5)
    max_tokens: int = Field(default=512, ge=1, le=1024)


@app.on_event("startup")
def load_model() -> None:
    global tokenizer, model
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, token=HF_TOKEN)
    dtype = torch.float16 if torch.cuda.is_available() else torch.float32
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_ID,
        token=HF_TOKEN,
        torch_dtype=dtype,
        device_map="auto",
        low_cpu_mem_usage=True,
    )
    model.eval()


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "model": MODEL_ID, "loaded": model is not None}


@app.post("/v1/chat/completions")
def chat_completions(
    request: ChatCompletionRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    if INFERENCE_BEARER_TOKEN:
        expected = f"Bearer {INFERENCE_BEARER_TOKEN}"
        if authorization is None or not secrets.compare_digest(authorization, expected):
            raise HTTPException(status_code=401, detail="Invalid inference token")
    if model is None or tokenizer is None:
        raise HTTPException(status_code=503, detail="Model is still loading")

    messages = [message.model_dump() for message in request.messages]
    try:
        prompt = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )
        inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
        with model_lock, torch.inference_mode():
            generated = model.generate(
                **inputs,
                max_new_tokens=min(request.max_tokens, 1024),
                do_sample=request.temperature > 0,
                temperature=max(request.temperature, 0.01),
                pad_token_id=tokenizer.eos_token_id,
                eos_token_id=tokenizer.eos_token_id,
            )
        new_tokens = generated[0][inputs["input_ids"].shape[-1]:]
        content = tokenizer.decode(new_tokens, skip_special_tokens=True).strip()
    except Exception as error:
        raise HTTPException(status_code=500, detail="Model inference failed") from error

    return {
        "id": f"chatcmpl-{uuid.uuid4().hex}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": request.model or MODEL_ID,
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": content},
            "finish_reason": "stop",
        }],
        "usage": {},
    }
