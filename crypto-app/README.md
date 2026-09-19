# CryptoAI PRO — Android APK (WebView wrapper)

`app/src/main/assets/index.html` = the single-file CryptoAI PRO web app.
The Kotlin side provides `window.AndroidBridge` (Binance/Bybit HMAC-signed requests, key storage,
HTTP proxy for OpenRouter/HuggingFace, notifications, TTS, haptics, foreground service, keep-screen-on).

## APK download
Every push that touches `crypto-app/**` builds a debug APK via GitHub Actions:
- Release (permanent link): https://github.com/Rusindu12/Rs-et/releases/tag/cryptoai-apk-latest
- Or: Actions tab → "CryptoAI PRO APK" run → `CryptoAI-PRO-debug-apk` artifact

## Build locally
Android Studio → Open `crypto-app/` → Build → Build APK(s) → `app/build/outputs/apk/debug/app-debug.apk`

## AndroidBridge API (JS → Kotlin, all synchronous)
| Method | Returns |
|---|---|
| `binanceSaveKeys(key, secret[, testnet])` / `bybitSaveKeys(...)` | – |
| `binanceStatus()` / `bybitStatus()` | JSON `{hasKeys,testnet,keyPreview,timeOffset,base}` |
| `binanceSyncTime()` / `bybitSyncTime()` | time offset (ms) |
| `binancePublic(path[, paramsJson])` / `bybitPublic(...)` | response body |
| `binanceSigned(method, path[, paramsJson])` / `bybitSigned(...)` | response body (HMAC signed) |
| `httpGet(url[, headersJson])`, `httpPost(url, body[, headersJson])`, `httpRequest(method,url,body,headersJson)` | response body |
| `notifySignal([title,] text)`, `speak(text)`, `toast(msg)`, `haptic([ms])` | – |
| `setAutoOn(bool)`, `setTradingActive(bool)`, `updateTradeStatus(text)`, `startBgService([text])`, `stopBgService()` | – |
| `setKeepScreenOn(bool)`, `apiBase()`, `setApiBase(url)`, `getPref(k)`, `setPref(k,v)` | – |
