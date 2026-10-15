# RS AI Hub — All-in-One AI APK 🤖✨

සියලුම AI features එක app එකකට! Free වෙන්න AI use කරන්න — API key එකක් නැතත්.

All-in-one AI app: **Chat · Image generation · Vision · Translate · Code · Homework · Voice** — 100% free with Pollinations, or bring your own API key (Groq, OpenAI, OpenRouter, Ollama, etc.).

## ✨ Features

| Feature | Description |
|---|---|
| 💬 **AI Chat** | Multi-persona streaming chat (Assistant, Teacher, Coder, Writer, Translator, Chef, Math Tutor, Business) |
| 🎨 **Imagine** | AI image generation (Flux, Turbo, Realism, Anime, GPT Image) with gallery & download |
| 🌍 **Translate** | Any language pair — Sinhala ↔ English and 100+ more |
| 📝 **Summarize** | Condense long text into key points |
| ✏️ **Rewrite** | Improve clarity, style, grammar |
| ✅ **Grammar Fix** | Spelling & grammar correction |
| 📧 **Email Writer** | Professional email drafts |
| 💻 **Code Helper** | Generate, explain & debug code |
| 📖 **Homework** | Step-by-step problem solving |
| 📋 **Study Notes** | Topic summaries for revision |
| 📖 **Story & Poem** | Creative writing |
| 📷 **Vision** | Attach images for AI analysis |
| 🎤 **Voice Input** | Speak in Sinhala or English |
| 🔊 **TTS** | AI reads replies aloud |
| 🌓 **Dark/Light** | Full theme support |
| 🌐 **Bilingual** | English / සිංහල (ස්වයං-පරිවර්තනය) |

## 💸 100% Free

Default mode uses **Pollinations.ai** — no API key, no account, no payment. Just install and go.

For unlimited access, get a free API key from:
- [Groq](https://console.groq.com) — Llama, Mixtral (free tier)
- [OpenRouter](https://openrouter.ai) — 100+ models (free credits)
- [Pollinations](https://enter.pollinations.ai) — their own API key

Or connect to your own **RS AI server** (see `server/` in this repo).

## 📦 APK Download

**👉 [Latest APK](https://github.com/Rusindu12/Rs-et/releases/tag/aihub-apk-latest)** — debug-signed, sideloadable.

## 🏗️ Build Locally

```bash
# Prerequisites: JDK 17 + Android SDK (or Android Studio)
cd ai-hub-app
gradle assembleDebug
# APK → app/build/outputs/apk/debug/app-debug.apk
```

Or push any change to trigger the CI → APK auto-published to GitHub Releases.

## 📖 Architecture

```
ai-hub-app/
├── app/src/main/
│   ├── assets/             ← The real app (HTML/CSS/JS)
│   │   ├── index.html      ← Single-page app
│   │   ├── app.css         ← Styling (dark glassmorphism)
│   │   ├── ai.js           ← AI provider layer
│   │   ├── app.js          ← UI controller
│   │   └── i18n.js         ← EN/SI translations
│   ├── java/.../           ← Native shell (Kotlin)
│   │   ├── MainActivity.kt ← WebView + file chooser + download
│   │   └── AndroidBridge.kt← TTS · STT · image save · share
│   └── res/                ← Icon, theme, strings
└── build.gradle.kts        ← AGP 8.5.2, Kotlin 1.9.24
```

The web assets run in a **WebView** with universal file access (so fetch to AI APIs works from `file://` origin). The native bridge provides TTS, speech recognition, image saving, and file picking — all optional (the same web app also runs in any browser as a standalone website).

## 🔧 AI Providers

| Provider | Setup | Models |
|---|---|---|
| 🌸 **Pollinations** (free) | Nothing — works out of the box | openai, mistral, llama, etc. |
| 🔑 **Custom** (OpenAI-compatible) | Base URL + API key + model name | Groq, OpenAI, OpenRouter, Ollama, etc. |
| 🤖 **RS AI Server** | Server URL + optional token | Your own RS-GPT model |

---

Made with ❤️ by the RS team.