# Binance AI Trader (Android APK)

Live Binance trading app for Android with an on-device AI signal engine.

## Features
- **Live prices & candlestick chart** via Binance WebSocket (kline / ticker streams)
- **AI signal engine** (runs on the phone): RSI 14, MACD, EMA 9/21/50 trend & crosses,
  Bollinger Bands, volume confirmation → `STRONG BUY / BUY / HOLD / SELL / STRONG SELL` with confidence %
- **Three trading modes**
  - `Paper` – simulated trades using real live prices (default, 10 000 USDT virtual balance)
  - `Testnet` – real orders on `testnet.binance.vision` (fake funds)
  - `Live` – real orders on your Binance Spot account
- **Auto-trade bot** – buys on STRONG BUY above your min-confidence, exits on SELL signals,
  take-profit and stop-loss levels per position
- **Portfolio** – open positions, PnL, trade history, wallet balances
- **Security** – API key/secret stored in Android `EncryptedSharedPreferences`; every signed
  request is HMAC-SHA256 signed in native Kotlin, so the secret never enters the WebView.

## Get the APK
Every push runs the **Build APK** GitHub Action which:
1. uploads `BinanceAITrader-debug.apk` + `BinanceAITrader-release.apk` as a workflow artifact, and
2. publishes them on a `build-N` pre-release under **Releases**.

Download `BinanceAITrader-release.apk` → allow "Install unknown apps" → install.

## Build locally
```bash
./gradlew assembleRelease
# → app/build/outputs/apk/release/app-release.apk
```
Requires JDK 17 and the Android SDK (compileSdk 34). Or open the folder in Android Studio.

### Optional: sign with your own keystore
Set these env vars before building (CI: add them as repository secrets and export them in the workflow):
`KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Without them the release APK
is signed with the debug key so it is still installable.

## Project layout
```
app/src/main/java/com/rset/binanceai/MainActivity.kt   # WebView host + secure native bridge
app/src/main/assets/www/index.html                     # UI
app/src/main/assets/www/app.js                         # market data, chart, trading, portfolio
app/src/main/assets/www/indicators.js                  # TA indicators + scoring engine
app/src/main/assets/www/bridge.js                      # JS ⇄ native bridge (browser fallback for dev)
.github/workflows/build-apk.yml                        # CI build + release
```

## Using API keys
Binance → API Management → create key with **Enable Spot & Margin Trading** only
(never enable withdrawals). For Testnet, create keys at https://testnet.binance.vision.
Enter them in the app under **Settings → Binance API keys**.

## Disclaimer
Signals are rule-based technical analysis, not financial advice. Trading crypto carries risk of loss.
Use Paper/Testnet mode first.
