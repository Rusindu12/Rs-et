# CryptoAI PRO — APK එක install කරන ආකාරය (සිංහල)

## 1. APK එක download කරන්න

**👉 https://github.com/Rusindu12/Rs-et/releases/download/cryptoai-apk-latest/CryptoAI-PRO.apk**

(හැම push එකකට පස්සේ GitHub Actions එකෙන් auto-build වෙනවා — release page එක:
https://github.com/Rusindu12/Rs-et/releases/tag/cryptoai-apk-latest)

> Android 7.0 (API 24) හෝ ඊට ඉහළ ඕනම phone එකක වැඩ කරයි. File එක ~3.7 MB.

## 2. Install කරන්න

1. APK එක phone එකට copy කරන්න (හෝ phone එකෙන්ම download කරන්න).
2. File Manager එකෙන් ඒක tap කරන්න.
3. **"Install unknown apps"** allow කරන්න කියලා අහයි → Settings → ඒ app එකට (Files/Chrome)
   allow කරන්න → ආපහු ඇවිත් Install.
4. Play Protect warning එකක් ආවොත් ("unknown developer") → **Install anyway**
   (මේක debug-signed නිසා — Play Store එකෙන් නෙවේ).

## 3. App එක use කරන්න (යතුරු කිසිවක් අවශ්‍ය නැහැ)

| Tab | මොකද කරන්නේ |
|---|---|
| 📈 **වෙළඳපොල** | Top volume / Gainers / Losers / ★ watchlist — search, 24h මිල වෙනස, mini graph |
| 🕯️ **ප්‍රස්තාරය** | Candles + EMA 20/50, Bollinger, volume, RSI. ඇඟිල්ල අදින්න → ඒ candle එකේ O/H/L/C පෙන්වයි |
| 🎯 **සංඥා** | **STRONG BUY → STRONG SELL** තීරණය + විශ්වාසය %, trend vs oscillator blocks, හේතු, දර්ශක 12, ATR මත entry/TP/SL, backtest |
| 💱 **වෙළඳාම** | **පුහුණු (paper) mode** — 10,000 USDT, 0.1% ගාස්තු, buy/sell, limit, TP/SL, history |
| 🤖 **රොබෝ** | Auto-bot: උපාය 4ක්, කොයින් කිහිපයක්, max positions, cooldown, දෛනික පාඩු සීමාව |

**භාෂාව:** උඩ දකුණේ **EN / සිං** බොත්තමෙන් සම්පූර්ණ app එක සිංහලෙන්.

**දත්ත:** Binance / Bybit / OKX (⚙ සැකසුම්වලින් තෝරන්න). ඉන්ටර්නෙට් නැත්නම් app එක
"⚠ නියැදි දත්ත" කියලා පැහැදිලිව පෙන්වලා නියැදි (demo) දත්ත මත වැඩ කරනවා — මිල සැබෑ නොවේ.

## 4. සැබෑ (live) වෙළඳාම — optional

⚙ **සැකසුම් → API යතුරු**:
* Binance/Bybit එකේ API යතුරක් හදන්න (Spot trading ON, **withdrawal OFF** ⚠️).
* යතුර + secret එක app එකට දාන්න → **Save** → **Test connection**.
* යතුරු **උපාංගයේම** SharedPreferences එකේ තියෙනවා; ඉල්ලීම් HMAC අත්සන් කරන්නේ Kotlin
  පැත්තෙන් — ඒ නිසා secret එක කිසිම web page එකකට හෝ ඉන්ටර්නෙට් එකට යන්නේ නැහැ.
* ⚙ එකේ **testnet** switch එකෙන් Binance testnet පාවිච්චි කරලා බලන්නත් පුළුවන්.

> ⚠️ **අවවාදයයි:** මෙය අධ්‍යාපනික මෙවලමක්. Crypto වෙළඳාම අවදානම් සහිතයි — මුදල් අහිමි විය හැක.
> සංඥා ආයෝජන උපදෙස් නොවේ. මුලින්ම paper mode එකෙන් උපාය පරීක්ෂා කරන්න.

## 5. AI පැහැදිලි කිරීම (optional)

⚙ → **AI explanation**: OpenRouter / HuggingFace / ඔබේම OpenAI-compatible endpoint එකක
යතුරක් දාන්න. නැත්නම් app එකේ **තමන්ගේම rule-based පැහැදිලි කිරීම** සිංහලෙන්ම ලැබෙනවා
(යතුරු නැතුවත් හරියටම වැඩ කරයි).

---

**Developer:** `arena/01a0bf18-rs-et` branch එකේ commit `1de6956` එකෙන් build වූවක්
(CI run: CryptoAI PRO APK ✅). Source: `crypto-app/`.
