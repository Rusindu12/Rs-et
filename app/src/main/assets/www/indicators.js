/* Technical indicators + rule-based "AI" scoring engine (runs fully on-device). */
window.TA = (function () {
  function sma(arr, n) {
    const out = new Array(arr.length).fill(null);
    let sum = 0;
    for (let i = 0; i < arr.length; i++) {
      sum += arr[i];
      if (i >= n) sum -= arr[i - n];
      if (i >= n - 1) out[i] = sum / n;
    }
    return out;
  }

  function ema(arr, n) {
    const out = new Array(arr.length).fill(null);
    const k = 2 / (n + 1);
    let prev = null;
    for (let i = 0; i < arr.length; i++) {
      if (prev === null) {
        if (i >= n - 1) {
          let s = 0; for (let j = i - n + 1; j <= i; j++) s += arr[j];
          prev = s / n; out[i] = prev;
        }
      } else {
        prev = arr[i] * k + prev * (1 - k);
        out[i] = prev;
      }
    }
    return out;
  }

  function rsi(closes, n = 14) {
    const out = new Array(closes.length).fill(null);
    let gain = 0, loss = 0;
    for (let i = 1; i < closes.length; i++) {
      const d = closes[i] - closes[i - 1];
      if (i <= n) {
        if (d > 0) gain += d; else loss -= d;
        if (i === n) { gain /= n; loss /= n; out[i] = loss === 0 ? 100 : 100 - 100 / (1 + gain / loss); }
      } else {
        gain = (gain * (n - 1) + Math.max(d, 0)) / n;
        loss = (loss * (n - 1) + Math.max(-d, 0)) / n;
        out[i] = loss === 0 ? 100 : 100 - 100 / (1 + gain / loss);
      }
    }
    return out;
  }

  function macd(closes, fast = 12, slow = 26, sig = 9) {
    const ef = ema(closes, fast), es = ema(closes, slow);
    const line = closes.map((_, i) => (ef[i] != null && es[i] != null) ? ef[i] - es[i] : null);
    const valid = line.filter(v => v != null);
    const sigValid = ema(valid, sig);
    const signal = new Array(closes.length).fill(null);
    let vi = 0;
    for (let i = 0; i < closes.length; i++) if (line[i] != null) signal[i] = sigValid[vi++];
    const hist = line.map((v, i) => (v != null && signal[i] != null) ? v - signal[i] : null);
    return { line, signal, hist };
  }

  function bollinger(closes, n = 20, mult = 2) {
    const mid = sma(closes, n);
    const upper = new Array(closes.length).fill(null), lower = new Array(closes.length).fill(null);
    for (let i = n - 1; i < closes.length; i++) {
      let s = 0; for (let j = i - n + 1; j <= i; j++) s += Math.pow(closes[j] - mid[i], 2);
      const sd = Math.sqrt(s / n);
      upper[i] = mid[i] + mult * sd; lower[i] = mid[i] - mult * sd;
    }
    return { mid, upper, lower };
  }

  function atr(candles, n = 14) {
    const trs = candles.map((c, i) => i === 0 ? c.h - c.l : Math.max(c.h - c.l, Math.abs(c.h - candles[i - 1].c), Math.abs(c.l - candles[i - 1].c)));
    return ema(trs, n);
  }

  /**
   * Scores the market between -100 (strong sell) and +100 (strong buy).
   * candles: [{t,o,h,l,c,v}]
   */
  function analyze(candles) {
    if (!candles || candles.length < 60) return { score: 0, signal: 'HOLD', confidence: 0, reasons: ['Waiting for enough candles…'], ind: {} };
    const closes = candles.map(c => c.c), vols = candles.map(c => c.v);
    const i = closes.length - 1;
    const r = rsi(closes)[i];
    const m = macd(closes);
    const e9 = ema(closes, 9), e21 = ema(closes, 21), e50 = ema(closes, 50);
    const bb = bollinger(closes);
    const volSma = sma(vols, 20)[i];
    const volRatio = volSma ? vols[i] / volSma : 1;
    const price = closes[i];
    const pctB = (bb.upper[i] != null) ? (price - bb.lower[i]) / (bb.upper[i] - bb.lower[i]) : 0.5;
    const reasons = [];
    let score = 0;

    // RSI (weight 25)
    if (r < 30) { score += 25; reasons.push(`RSI ${r.toFixed(1)} oversold → bullish reversal zone`); }
    else if (r < 40) { score += 12; reasons.push(`RSI ${r.toFixed(1)} approaching oversold`); }
    else if (r > 70) { score -= 25; reasons.push(`RSI ${r.toFixed(1)} overbought → bearish pressure`); }
    else if (r > 60) { score -= 12; reasons.push(`RSI ${r.toFixed(1)} approaching overbought`); }
    else reasons.push(`RSI ${r.toFixed(1)} neutral`);

    // MACD (weight 25)
    const h = m.hist[i], hPrev = m.hist[i - 1];
    if (h != null && hPrev != null) {
      if (h > 0 && hPrev <= 0) { score += 25; reasons.push('MACD bullish crossover just occurred'); }
      else if (h < 0 && hPrev >= 0) { score -= 25; reasons.push('MACD bearish crossover just occurred'); }
      else if (h > 0 && h > hPrev) { score += 12; reasons.push('MACD histogram rising (bullish momentum)'); }
      else if (h < 0 && h < hPrev) { score -= 12; reasons.push('MACD histogram falling (bearish momentum)'); }
      else if (h > 0) { score += 5; } else { score -= 5; }
    }

    // EMA trend (weight 25)
    let trend = 'Sideways';
    if (e9[i] != null && e21[i] != null && e50[i] != null) {
      if (e9[i] > e21[i] && e21[i] > e50[i]) { score += 20; trend = 'Uptrend'; reasons.push('EMA 9 > 21 > 50 — aligned uptrend'); }
      else if (e9[i] < e21[i] && e21[i] < e50[i]) { score -= 20; trend = 'Downtrend'; reasons.push('EMA 9 < 21 < 50 — aligned downtrend'); }
      else if (e9[i] > e21[i]) { score += 8; trend = 'Weak up'; }
      else { score -= 8; trend = 'Weak down'; }
      if (e9[i - 1] != null && e9[i - 1] <= e21[i - 1] && e9[i] > e21[i]) { score += 10; reasons.push('Fresh EMA 9/21 golden cross'); }
      if (e9[i - 1] != null && e9[i - 1] >= e21[i - 1] && e9[i] < e21[i]) { score -= 10; reasons.push('Fresh EMA 9/21 death cross'); }
    }

    // Bollinger (weight 15)
    if (pctB < 0) { score += 15; reasons.push('Price below lower Bollinger band'); }
    else if (pctB < 0.2) { score += 8; }
    else if (pctB > 1) { score -= 15; reasons.push('Price above upper Bollinger band'); }
    else if (pctB > 0.8) { score -= 8; }

    // Volume confirmation (weight 10) – amplifies the direction of the last candle
    const lastDir = candles[i].c >= candles[i].o ? 1 : -1;
    if (volRatio > 1.8) { score += 10 * lastDir; reasons.push(`Volume ${volRatio.toFixed(1)}× average confirms ${lastDir > 0 ? 'buyers' : 'sellers'}`); }
    else if (volRatio > 1.3) { score += 5 * lastDir; }

    // Confluence bonuses – reversal (oversold + momentum turning) and trend continuation (pullback)
    if (h != null && hPrev != null) {
      if (r < 35 && h > hPrev) { score += 15; reasons.push('Oversold with momentum turning up — reversal setup'); }
      if (r > 65 && h < hPrev) { score -= 15; reasons.push('Overbought with momentum fading — reversal setup'); }
      if (trend === 'Uptrend' && r >= 40 && r <= 60 && h > 0) { score += 15; reasons.push('Healthy pullback inside uptrend'); }
      if (trend === 'Downtrend' && r >= 40 && r <= 60 && h < 0) { score -= 15; reasons.push('Weak bounce inside downtrend'); }
    }

    score = Math.round(Math.max(-100, Math.min(100, score)));
    const confidence = Math.min(99, Math.round(50 + Math.abs(score) / 2));
    let signal = 'HOLD';
    if (score >= 50) signal = 'STRONG BUY';
    else if (score >= 25) signal = 'BUY';
    else if (score <= -50) signal = 'STRONG SELL';
    else if (score <= -25) signal = 'SELL';

    return {
      score, signal, confidence, reasons: reasons.slice(0, 4),
      ind: { rsi: r, macdHist: h, ema9: e9[i], ema21: e21[i], pctB, volRatio, trend, atr: atr(candles)[i] },
      series: { ema9: e9, ema21: e21, bb }
    };
  }

  return { sma, ema, rsi, macd, bollinger, atr, analyze };
})();
