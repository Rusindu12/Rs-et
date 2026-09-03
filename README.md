# RS TradingAI 🤖📈

**Live Binance Trading AI** — Android app (APK)

## ✨ Features

- **Live market data** — real-time Binance prices via WebSocket (24/7)
- **Candlestick chart** — TradingView Lightweight Charts, EMA20/EMA50 overlays, volume
- **6 timeframes** — 1m · 5m · 15m · 1H · 4H · 1D
- **22 popular pairs** — BTC, ETH, SOL, PEPE, … (USDT)
- **AI Signal Engine** — weighted scoring over 6 factors:
  EMA trend ribbon (20/50/200), RSI(14), MACD(12,26,9), Bollinger %B, ROC momentum, volume confirmation → `STRONG BUY / BUY / HOLD / SELL / STRONG SELL` with confidence % + Sinhala explanation
- **Auto-Trading Bot** — enters on strong AI signals, auto take-profit / stop-loss, AI-reverse exit
- **3 trading modes**
  - 🟢 **Paper** — virtual $10,000, real data, zero risk (default)
  - 🟡 **Testnet** — testnet.binance.vision fake funds, real API flow
  - 🔴 **Live** — real money on Binance (your API keys, stays on your phone)
- **Performance stats** — P&L, win rate, full trade history
- **Signal feed** — every signal change logged

## 🔐 Security

- API keys are stored **only** in the phone's localStorage — never sent anywhere except signed Binance API requests
- HMAC-SHA256 request signing (WebCrypto + pure-JS verified fallback)
- Recommendation: create API keys **without** withdrawal permission

## ⚠️ Disclaimer

Crypto trading is risky. The AI engine is algorithmic technical analysis — **not financial advice**, no profit guarantee. Start in Paper/Testnet mode. Use at your own risk.

## 🛠 Build

```bash
gradle assembleDebug
# → app/build/outputs/apk/debug/app-debug.apk
```

Or just push — GitHub Actions builds the APK automatically (see `.github/workflows/build-apk.yml`, artifact lands in `apk/`).

## 🧪 Tests

```bash
node tests/engine.test.js   # 42 unit tests — indicators, SHA-256/HMAC, AI scoring
node tests/app.smoke.js     # 17 smoke tests — full app boot + trading flows
```

## 📁 Structure

```
app/src/main/
├── java/com/rset/trading/MainActivity.java   # WebView shell (zero external deps)
├── assets/app.html                            # full trading UI
├── assets/js/engine.js                        # indicators + AI + Binance signing
└── assets/js/lightweight-charts.js            # TradingView charts (Apache-2.0)
```
