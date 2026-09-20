# CryptoAI PRO — website

The public site: a landing page (EN + සිංහල) and the **web app** itself, plus PWA
support so it can be installed to the home screen.

```
web/
├── index.html            landing page (bilingual, live price strip, phone preview, FAQ)
├── app/                  the web app — index.html, app.js, ta.js
├── manifest.webmanifest  PWA: name, icons, start_url ./app/, shortcuts
├── sw.js                 service worker: offline shell, never caches exchange APIs
├── icons/                generated icons (192/512/maskable/apple-touch/favicon)
├── og-cover.png          social share image (1200×630)
└── tools/make_icons.py   regenerates the icons + cover (pure Python, no deps)
```

`web/app/` is a copy of `crypto-app/app/src/main/assets/` — the **same** terminal that
runs inside the APK. The deploy workflow re-copies those files on every build, so the
site and the app can never drift apart.

## Deploy (GitHub Pages)

1. Repo → **Settings → Pages → Build and deployment → Source: `GitHub Actions`** (one-time).
2. Merge this branch into `main` (or run the **Deploy website (GitHub Pages)** workflow manually).
3. The site appears at `https://<owner>.github.io/<repo>/` — for this repo:
   `https://rusindu12.github.io/Rs-et/`

If you prefer branch-based Pages (Source: *Deploy from a branch*), GitHub only offers `/`
(root) or `/docs` — copy this folder to `/docs` in that case.

## Local preview

```bash
cd web && python3 -m http.server 8080     # → http://localhost:8080
```
The landing page and the web app both work from a plain static server (the app falls
back to clearly-labelled demo data when it cannot reach an exchange).

## Note on live trading

The web app runs the same code as the Android app, but real orders need the Kotlin
bridge (HMAC signing on the device), so live trading is Android-only by design —
the browser build is paper mode.

## Regenerate the artwork

```bash
python3 web/tools/make_icons.py   # needs no third-party packages
```
