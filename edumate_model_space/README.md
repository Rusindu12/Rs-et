---
title: EduMate Llama 3.2 Inference
emoji: 🎓
colorFrom: purple
colorTo: indigo
sdk: docker
app_port: 7860
---

# EduMate self-hosted model endpoint

This optional Docker Space loads `meta-llama/Llama-3.2-3B-Instruct` and serves an OpenAI-compatible `POST /v1/chat/completions` route for `edumate_backend`.

## Deploy

1. Create a Hugging Face **Docker Space** and copy this directory's contents into its Space repository.
2. Confirm the model license/access terms in Hugging Face. If the model repository is gated, accept its license and add `HF_TOKEN` as a **Space secret** so the weights can be downloaded. This token stays in the model host; it does not belong in Flutter.
3. Optional: set `INFERENCE_BEARER_TOKEN` as a Space secret. If set, use the same value as `LLM_API_KEY` in the FastAPI backend's Render secrets.
4. After the Space reports ready, set `LLM_ENDPOINT=https://<space-name>.hf.space/v1/chat/completions` and `LLM_MODEL=meta-llama/Llama-3.2-3B-Instruct` on the EduMate FastAPI backend.
5. Check `https://<space-name>.hf.space/health` and then `https://<backend>/api/health`.

## Free-tier reality check

This is an inference **template**, not a guarantee that Llama 3.2 3B will fit or run responsively on every free Space. Model access may be gated; first startup downloads several gigabytes; CPU inference may be very slow; Spaces can sleep, cold-start, hit RAM limits, or change their free quotas. If the free CPU Space runs out of memory, use a smaller open model or a quantized model server, or choose compatible hardware. Never expose an unprotected public inference endpoint to unrestricted traffic.
