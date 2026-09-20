# CryptoAI PRO — Android app (Sinhala + English crypto terminal)

A market/chart/signal/trading terminal inside a WebView shell: **markets dashboard, candlestick
charts with EMA/Bollinger/volume/RSI, a rule-based signal engine, paper + live trading, an
auto-bot with risk limits, price alerts and an optional AI explanation.**

```
crypto-app/app/src/main/assets/
├── index.html   layout + dark Material-ish theme (EN/සිංහල)
├── ta.js        pure TA engine: EMA/SMA/RSI/MACD/Bollinger/ATR/Stochastic, signal scoring, backtester
└── app.js       market data (Binance/Bybit/OKX + WebSocket), chart renderer, paper/live trading,
                 bot strategies, alerts, i18n, settings, persistence
```

The Kotlin side provides `window.AndroidBridge` (Binance/Bybit HMAC-signed requests, key storage,
HTTP proxy for OpenRouter/HuggingFace, notifications, TTS, haptics, foreground service, keep-screen-on).

## APK download

Every push that touches `crypto-app/**` builds a debug APK via GitHub Actions:
- Release (permanent link): https://github.com/Rusindu12/Rs-et/releases/tag/cryptoai-apk-latest
- Or: Actions tab → "CryptoAI PRO APK" run → `CryptoAI-PRO-debug-apk` artifact

## What it does

| Tab | Contents |
|---|---|
| 📈 **Markets** | top-volume / gainers / losers / watchlist, search, live 24h change + sparkline |
| 🕯️ **Chart** | last 140 candles, EMA 20/50, Bollinger, volume, RSI(14) panel, drag to inspect, timeframe 1m…1d |
| 🎯 **Signal** | blended verdict (STRONG BUY … STRONG SELL) with confidence, trend vs oscillator blocks, reasons, 12 indicator metrics, ATR-based entry/target/stop, 500-candle backtest, optional AI explanation |
| 💱 **Trade** | paper mode (10,000 USDT, 0.1% fee, long/short, TP/SL, limit orders, history) and live mode (Binance/Bybit spot, keys signed on-device) |
| 🤖 **Bot** | 4 strategies (AI signal / trend / reversion / breakout), multi-symbol, TP/SL, max positions, cooldown, daily-loss stop, activity log, notifications |

Notes:
- **No account is needed** for prices, signals, charts or paper trading.
- If no exchange is reachable the app keeps working on clearly-labelled **simulated demo data**.
- Live trading needs API keys with *trading* enabled and **withdrawal disabled**; requests are signed
  by the Kotlin bridge, so the secret never leaves the device (and never enters a web page).
- Educational tool — not financial advice.

## Verify the web layer locally

```bash
cd crypto-app/app/src/main/assets
python3 -m http.server 8000      # then open http://localhost:8000 (paper mode only)
```

The `ta.js` engine is dependency-free and also runs in Node:

```bash
node -e "const TA=require('./ta.js'); console.log(TA.analyze(candles))"
```

## Build locally

Android Studio → Open `crypto-app/` → Build → Build APK(s) → `app/build/outputs/apk/debug/app-debug.apk`
