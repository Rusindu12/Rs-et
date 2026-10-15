# EduMate AI FastAPI backend

මෙම lightweight backend එක Flutter app එකේ AI chat, automatic DuckDuckGo search, health check සහ PDF export endpoints සපයයි. Model weights/API provider keys mobile APK එකට නොයයි. Backend එක self-hosted, OpenAI-compatible chat-completions URL එකකට කතා කරයි.

## Run local

```bash
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\\Scripts\\Activate.ps1
pip install -r requirements.txt
cp .env.example .env           # Windows: copy .env.example .env
# .env තුළ LLM_ENDPOINT එක සකසන්න (optional for API/demo mode)
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- `GET /api/health` — backend/model/search status
- `POST /api/chat` — `{message, context, history}` → `{reply, provider, sources}`
- `POST /api/export/chat.pdf` — conversation PDF
- `POST /api/export/quiz.pdf` — quiz result PDF
- `GET /docs` — interactive OpenAPI docs

`LLM_ENDPOINT` සම්පූර්ණ OpenAI-compatible `/v1/chat/completions` URL එක විය යුතුය. අවශ්‍ය නම් `LLM_API_KEY` secret එක server environment එකේ පමණක් සකසන්න. Search logic එක “latest/current/today/අලුත්ම/අද” වැනි කාල-සංවේදී query සඳහා පමණක් DuckDuckGo (`ddgs`) භාවිතා කරයි; dependency/network නැතිනම් sources හිස්ව තබා chat එක දිගටම ක්‍රියා කරයි.

## Deploy

Render service root `edumate_backend`, build `pip install -r requirements.txt`, start `uvicorn main:app --host 0.0.0.0 --port $PORT`, health `/api/health`. `LLM_ENDPOINT`, optional `LLM_API_KEY`, `LLM_MODEL`, `CORS_ORIGINS` secrets/environment variables ලෙස එක් කරන්න. Free hosting quotas, sleep සහ model cold start සීමා පරීක්ෂා කරන්න.

Llama 3.2 3B free hosting එකේ අනිවාර්යයෙන්ම ගැළපෙන බවට සහතිකයක් නැහැ. HF Space එක public OpenAI-compatible endpoint එකක් expose කර තිබිය යුතුය; gated model එකකට host-side `HF_TOKEN`/license acceptance අවශ්‍ය විය හැක. Backend `.env` සහ host secrets source control එකට commit නොකරන්න.

## Sinhala PDF font

ReportLab core fonts Sinhala glyphs සම්පූර්ණයෙන් render නොකරයි. Noto Sans Sinhala වැනි license-compatible TTF font එකක් backend image/server එකට ලබාදී `EDUMATE_PDF_FONT_PATH=/path/to/NotoSansSinhala-Regular.ttf` සකසන්න. Font නොමැතිව PDF response එක තවම නිපදවෙයි, නමුත් Sinhala glyphs අඩුවිය හැක.

## Security before real students

1. `CORS_ORIGINS` wildcard එක ඉවත් කර අවශ්‍ය origins පමණක් allow කරන්න.
2. Firebase ID token verify කිරීම, per-user/IP rate limit, abuse controls සහ request limits එක් කරන්න.
3. Firestore rules least-privilege ලෙස review කරන්න (`firestore.rules.example`).
4. Sinhala syllabus answers, citations සහ age-appropriate output ගුරුවරුන් සමඟ validate කරන්න. Search results untrusted input ලෙස සලකන්න.
5. Student data privacy/retention, parental consent, safety and incident handling සැලසුම් කරන්න.

## Tests

```bash
python -m unittest discover -s tests -v
```
