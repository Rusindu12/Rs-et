# RS AI server — all-in-one image (model + server + web UI + PWA)
# Works on: Hugging Face Spaces (Docker SDK), Render, Railway, Fly.io, any VPS.
#
#   docker build -t rs-ai .
#   docker run -p 7860:7860 -e RS_API_KEY=gsk_... rs-ai
#
# Environment variables (see server/README.md):
#   RS_PROVIDER   auto | local | groq | openai | gemini | openrouter | deepseek | custom
#   RS_API_KEY    external AI API key (activates smart mode ⚡)
#   RS_API_TOKEN  optional — if set, /chat & /v1 require "Authorization: Bearer <token>"
#   PORT          listen port (default 7860 — matches Hugging Face Spaces)
FROM python:3.11-slim

WORKDIR /app

# CPU-only PyTorch keeps the image small (~2 GB total)
RUN pip install --no-cache-dir "numpy<2" \
 && pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch==2.2.2

COPY server/requirements.txt server/requirements.txt
RUN pip install --no-cache-dir -r server/requirements.txt

COPY . .

ENV PORT=7860
EXPOSE 7860

CMD ["sh", "-c", "uvicorn server.main:app --host 0.0.0.0 --port ${PORT}"]
