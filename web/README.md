# CryptoAI PRO — website

The public site: a landing page (EN + සිංහල) and the **web app** itself, plus PWA
support so it can be installed to the home screen.

```
web/
├── index.html            landing page: hero + animated chart, live price strip, stats band,
│                         interactive live demo (real ta.js on live candles), phone preview,
│                         features, included-matrix, install, safety, FAQ
├── robots.txt · sitemap.xml  search-engine files
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

1. The workflow now asks GitHub to create the Pages site itself (`enablement: true`). If the
   token is not allowed to do that, enable it once by hand:
   **Settings → Pages → Build and deployment → Source: `GitHub Actions`**.
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

## The live demo on the landing page

The `#demo` section loads candles straight from Binance and runs **`app/ta.js`** — the exact
engine file the APK ships — in the visitor's browser, then shows the verdict, the confidence,
the reasons, ATR-based entry/target/stop, six indicator metrics and a fee-aware backtest on the
same candles. If the exchange is unreachable it falls back to clearly-labelled synthetic candles
(“the engine and the maths are real, the prices are not”), so the section never lies about data.

## Note on live trading

The web app runs the same code as the Android app, but real orders need the Kotlin
bridge (HMAC signing on the device), so live trading is Android-only by design —
the browser build is paper mode.

## Regenerate the artwork

```bash
python3 web/tools/make_icons.py   # needs no third-party packages
```
