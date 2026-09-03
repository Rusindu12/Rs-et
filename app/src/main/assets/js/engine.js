/* ============================================================
   RS TradingAI — Core Engine
   Indicators + AI signal scoring + Binance HMAC signing
   (Pure functions — testable in Node.js and browsers/WebView)
   ============================================================ */
(function (root) {
  'use strict';

  /* ---------------- SHA-256 / HMAC (pure JS fallback) ---------------- */
  // Compact SHA-256 implementation (public-domain style bitwise math)
  var SHA256 = (function () {
    var K = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ];
    function rotr(x, n) { return (x >>> n) | (x << (32 - n)); }

    function sha256Bytes(bytes) {
      // bytes: Uint8Array -> Uint8Array(32)
      var len = bytes.length;
      var bitLenHi = Math.floor(len / 0x20000000);
      var bitLenLo = (len << 3) >>> 0;

      // padding
      var withOne = len + 1;
      var padded = Math.ceil((withOne + 8) / 64) * 64; // multiple of 64
      var m = new Uint8Array(padded);
      m.set(bytes);
      m[len] = 0x80;

      var dv = new DataView(m.buffer);
      dv.setUint32(padded - 8, bitLenHi);
      dv.setUint32(padded - 4, bitLenLo);

      var H = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
      ];

      var w = new Int32Array(64);

      for (var off = 0; off < padded; off += 64) {
        for (var i = 0; i < 16; i++) {
          w[i] = dv.getInt32(off + i * 4);
        }
        for (var j = 16; j < 64; j++) {
          var s0 = rotr(w[j - 15], 7) ^ rotr(w[j - 15], 18) ^ (w[j - 15] >>> 3);
          var s1 = rotr(w[j - 2], 17) ^ rotr(w[j - 2], 19) ^ (w[j - 2] >>> 10);
          w[j] = (w[j - 16] + s0 + w[j - 7] + s1) | 0;
        }

        var a = H[0], b = H[1], c = H[2], d = H[3], e = H[4], f = H[5], g = H[6], h = H[7];

        for (var k = 0; k < 64; k++) {
          var S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
          var ch = (e & f) ^ (~e & g);
          var t1 = (h + S1 + ch + K[k] + w[k]) | 0;
          var S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
          var maj = (a & b) ^ (a & c) ^ (b & c);
          var t2 = (S0 + maj) | 0;
          h = g; g = f; f = e; e = (d + t1) | 0;
          d = c; c = b; b = a; a = (t1 + t2) | 0;
        }

        H[0] = (H[0] + a) | 0; H[1] = (H[1] + b) | 0; H[2] = (H[2] + c) | 0; H[3] = (H[3] + d) | 0;
        H[4] = (H[4] + e) | 0; H[5] = (H[5] + f) | 0; H[6] = (H[6] + g) | 0; H[7] = (H[7] + h) | 0;
      }

      var out = new Uint8Array(32);
      var odv = new DataView(out.buffer);
      for (var x = 0; x < 8; x++) odv.setUint32(x * 4, H[x] >>> 0);
      return out;
    }

    function utf8Bytes(str) {
      // encodeURIComponent-based UTF-8 (handles all code points)
      var s = unescape(encodeURIComponent(str));
      var b = new Uint8Array(s.length);
      for (var i = 0; i < s.length; i++) b[i] = s.charCodeAt(i) & 0xff;
      return b;
    }

    function toHex(bytes) {
      var h = '';
      for (var i = 0; i < bytes.length; i++) h += ('0' + bytes[i].toString(16)).slice(-2);
      return h;
    }

    return {
      hex: function (str) { return toHex(sha256Bytes(utf8Bytes(str))); },
      bytes: sha256Bytes,
      utf8Bytes: utf8Bytes,
      toHex: toHex
    };
  })();

  function hmacSha256Hex(secretStr, messageStr) {
    // HMAC construction over SHA-256 (block size 64)
    var key = SHA256.utf8Bytes(secretStr);
    if (key.length > 64) key = SHA256.bytes(key);
    while (key.length < 64) {
      var grown = new Uint8Array(64);
      grown.set(key);
      key = grown;
    }
    var oKey = new Uint8Array(64), iKey = new Uint8Array(64);
    for (var i = 0; i < 64; i++) {
      oKey[i] = key[i] ^ 0x5c;
      iKey[i] = key[i] ^ 0x36;
    }
    var msgBytes = SHA256.utf8Bytes(messageStr);

    var innerInput = new Uint8Array(64 + msgBytes.length);
    innerInput.set(iKey);
    innerInput.set(msgBytes, 64);
    var innerHash = SHA256.bytes(innerInput);

    var outerInput = new Uint8Array(64 + 32);
    outerInput.set(oKey);
    outerInput.set(innerHash, 64);
    return SHA256.toHex(SHA256.bytes(outerInput));
  }

  async function hmacSign(secret, message) {
    // Prefer WebCrypto when available (secure context); fall back to pure JS
    if (root.crypto && root.crypto.subtle && root.crypto.subtle.importKey) {
      try {
        var enc = new TextEncoder();
        var key = await root.crypto.subtle.importKey(
          'raw', enc.encode(secret),
          { name: 'HMAC', hash: 'SHA-256' },
          false, ['sign']
        );
        var sig = await root.crypto.subtle.sign('HMAC', key, enc.encode(message));
        var arr = new Uint8Array(sig);
        var h = '';
        for (var i = 0; i < arr.length; i++) h += ('0' + arr[i].toString(16)).slice(-2);
        return h;
      } catch (e) {
        // fall through to pure JS
      }
    }
    return hmacSha256Hex(secret, message);
  }

  /* ---------------- Indicators ---------------- */

  function sma(values, period) {
    if (values.length < period) return null;
    var sum = 0;
    for (var i = values.length - period; i < values.length; i++) sum += values[i];
    return sum / period;
  }

  function emaSeries(values, period) {
    if (values.length < period) return [];
    var out = [];
    var k = 2 / (period + 1);
    var prev = values.slice(0, period).reduce(function (a, b) { return a + b; }, 0) / period;
    out[period - 1] = prev;
    for (var i = period; i < values.length; i++) {
      prev = values[i] * k + prev * (1 - k);
      out[i] = prev;
    }
    return out; // sparse array up to index period-1
  }

  function ema(values, period) {
    var s = emaSeries(values, period);
    return s.length ? s[s.length - 1] : null;
  }

  function rsi(closes, period) {
    period = period || 14;
    if (closes.length < period + 1) return null;
    var gains = 0, losses = 0;
    // Wilder smoothing
    for (var i = 1; i <= period; i++) {
      var d = closes[i] - closes[i - 1];
      if (d >= 0) gains += d; else losses -= d;
    }
    var avgGain = gains / period, avgLoss = losses / period;
    for (var j = period + 1; j < closes.length; j++) {
      var dj = closes[j] - closes[j - 1];
      var g = dj > 0 ? dj : 0, l = dj < 0 ? -dj : 0;
      avgGain = (avgGain * (period - 1) + g) / period;
      avgLoss = (avgLoss * (period - 1) + l) / period;
    }
    if (avgLoss === 0) return 100;
    var rs = avgGain / avgLoss;
    return 100 - 100 / (1 + rs);
  }

  function macd(closes) {
    if (closes.length < 35) return null;
    var e12 = emaSeries(closes, 12);
    var e26 = emaSeries(closes, 26);
    var macdLine = [];
    for (var i = 26 - 1; i < closes.length; i++) {
      if (e12[i] == null || e26[i] == null) continue;
      macdLine.push({ i: i, v: e12[i] - e26[i] });
    }
    if (macdLine.length < 9) return null;
    var vals = macdLine.map(function (x) { return x.v; });
    var sigSeries = emaSeries(vals, 9);
    var last = macdLine[macdLine.length - 1];
    var sigLast = sigSeries[sigSeries.length - 1];
    var prev = macdLine[macdLine.length - 2];
    var sigPrev = sigSeries[sigSeries.length - 2];
    return {
      macd: last.v,
      signal: sigLast,
      hist: last.v - sigLast,
      prevHist: (prev.v - (sigPrev != null ? sigPrev : sigLast))
    };
  }

  function bollinger(closes, period, mult) {
    period = period || 20; mult = mult || 2;
    if (closes.length < period) return null;
    var slice = closes.slice(closes.length - period);
    var mean = slice.reduce(function (a, b) { return a + b; }, 0) / period;
    var variance = slice.reduce(function (a, b) { return a + (b - mean) * (b - mean); }, 0) / period;
    var sd = Math.sqrt(variance);
    return {
      mid: mean,
      upper: mean + mult * sd,
      lower: mean - mult * sd,
      pctB: (closes[closes.length - 1] - (mean - mult * sd)) / (2 * mult * sd || 1e-10)
    };
  }

  function atr(candles, period) {
    period = period || 14;
    if (candles.length < period + 1) return null;
    var trs = [];
    for (var i = 1; i < candles.length; i++) {
      var h = candles[i].high, l = candles[i].low, pc = candles[i - 1].close;
      trs.push(Math.max(h - l, Math.abs(h - pc), Math.abs(l - pc)));
    }
    var sum = 0;
    for (var j = 0; j < period; j++) sum += trs[j];
    var a = sum / period;
    for (var k = period; k < trs.length; k++) a = (a * (period - 1) + trs[k]) / period;
    return a;
  }

  /* ---------------- AI Signal Engine ---------------- */
  // Weighted multi-factor scoring: result score in [-100, +100]
  function computeSignal(candles) {
    if (!candles || candles.length < 60) {
      return { ok: false, reason: 'Not enough candle data (need 60+, got ' + (candles ? candles.length : 0) + ')' };
    }
    var closes = candles.map(function (c) { return c.close; });
    var vols = candles.map(function (c) { return c.volume; });
    var last = closes[closes.length - 1];

    var factors = [];

    // 1) Trend: EMA ribbon alignment (weight 25)
    var e20 = ema(closes, 20), e50 = ema(closes, 50), e200 = ema(closes, 200);
    var trendScore = 0;
    if (e20 != null && e50 != null) trendScore += (e20 > e50 ? 50 : -50);
    if (e200 != null) trendScore += (last > e200 ? 50 : -50);
    factors.push({
      name: 'Trend (EMA 20/50/200)', weight: 25,
      value: trendScore, // -100..100
      text: (e20 != null && e20 > e50 ? 'EMA20 > EMA50 (uptrend)' : 'EMA20 < EMA50 (downtrend)') +
        (e200 != null ? (last > e200 ? ' · price above EMA200' : ' · price below EMA200') : '')
    });

    // 2) RSI (weight 20) — contribution capped at ±60 because in strong trends
    // RSI stays extreme (trend-riding), so it should not fully veto the trend.
    var r = rsi(closes, 14);
    var rsiScore = 0;
    if (r != null) {
      if (r <= 30) rsiScore = Math.min(60, (30 - r) * 3 + 20);        // oversold -> buy
      else if (r >= 70) rsiScore = -Math.min(60, (r - 70) * 3 + 20);  // overbought -> sell
      else rsiScore = (50 - r) * 1.0; // mild mean-reversion
    }
    factors.push({
      name: 'RSI (14)', weight: 20, value: rsiScore,
      text: r == null ? 'n/a' : r.toFixed(1) + (r <= 30 ? ' · oversold' : r >= 70 ? ' · overbought' : ' · neutral')
    });

    // 3) MACD (weight 20)
    var m = macd(closes);
    var macdScore = 0;
    if (m != null) {
      var norm = Math.max(-100, Math.min(100, (m.hist / (last * 0.002 || 1e-10)) * 40));
      macdScore = norm;
      if (m.hist > 0 && m.prevHist <= 0) macdScore = Math.max(macdScore, 70);  // fresh bullish cross
      if (m.hist < 0 && m.prevHist >= 0) macdScore = Math.min(macdScore, -70); // fresh bearish cross
    }
    factors.push({
      name: 'MACD (12,26,9)', weight: 20, value: macdScore,
      text: m == null ? 'n/a' : 'hist ' + m.hist.toPrecision(3) + (m.hist > 0 ? ' · bullish' : ' · bearish')
    });

    // 4) Bollinger position (weight 15) — capped at ±60 (band-riding in trends)
    var bb = bollinger(closes, 20, 2);
    var bbScore = 0;
    if (bb != null) {
      if (bb.pctB <= 0.05) bbScore = 60;
      else if (bb.pctB >= 0.95) bbScore = -60;
      else bbScore = (0.5 - bb.pctB) * 90; // below mid -> buy bias
    }
    factors.push({
      name: 'Bollinger %B', weight: 15, value: bbScore,
      text: bb == null ? 'n/a' : (bb.pctB * 100).toFixed(0) + '% of band' +
        (bb.pctB <= 0.1 ? ' · near lower band' : bb.pctB >= 0.9 ? ' · near upper band' : '')
    });

    // 5) Momentum (weight 10): 10-bar rate of change
    var momScore = 0, roc = null;
    if (closes.length >= 11) {
      roc = (last - closes[closes.length - 11]) / closes[closes.length - 11] * 100;
      momScore = Math.max(-100, Math.min(100, roc * 25));
    }
    factors.push({
      name: 'Momentum (ROC 10)', weight: 10, value: momScore,
      text: roc == null ? 'n/a' : roc.toFixed(2) + '% / 10 bars'
    });

    // 6) Volume confirmation (weight 10)
    var volAvg = sma(vols, 20);
    var volRatio = volAvg ? vols[vols.length - 1] / volAvg : 1;
    var volScore = 0;
    if (volRatio > 1.5) volScore = (last >= closes[closes.length - 2] ? 60 : -60); // big move w/ volume
    factors.push({
      name: 'Volume vs avg20', weight: 10, value: volScore,
      text: volRatio ? volRatio.toFixed(2) + 'x' : 'n/a'
    });

    var totalWeight = factors.reduce(function (a, f) { return a + f.weight; }, 0);
    var score = factors.reduce(function (a, f) { return a + f.value * f.weight; }, 0) / totalWeight;
    score = Math.max(-100, Math.min(100, score));

    var label, level;
    if (score >= 55) { label = 'STRONG BUY'; level = 4; }
    else if (score >= 20) { label = 'BUY'; level = 3; }
    else if (score > -20) { label = 'HOLD'; level = 2; }
    else if (score > -55) { label = 'SELL'; level = 1; }
    else { label = 'STRONG SELL'; level = 0; }

    var confidence = Math.round(Math.min(100, Math.abs(score)));

    // ATR-based suggested SL/TP percentages
    var a = atr(candles, 14);
    var atrPct = a ? (a / last) * 100 : 1.5;

    return {
      ok: true,
      score: Math.round(score * 10) / 10,
      label: label,
      level: level,
      confidence: confidence,
      factors: factors,
      rsi: r,
      atrPct: Math.round(atrPct * 100) / 100,
      e20: e20, e50: e50, e200: e200,
      macd: m ? m.hist : null,
      bbPctB: bb ? bb.pctB : null,
      volRatio: volRatio,
      price: last,
      ts: Date.now()
    };
  }

  // Sinhala summary generator
  function sinhalaSummary(sig) {
    if (!sig || !sig.ok) return 'Data ප්‍රමාණවත් නෑ — ටිකක් බලාගෙන ඉන්න.';
    var s = sig.label === 'STRONG BUY' ? 'ශක්තිමත් ගනුදෙනු (BUY) සංඥාවක්' :
      sig.label === 'BUY' ? 'මිලදී ගැනීමේ (BUY) සංඥාවක්' :
        sig.label === 'SELL' ? 'අලෙවිකරණ (SELL) සංඥාවක්' :
          sig.label === 'STRONG SELL' ? 'ශක්තිමත් අලෙවි (STRONG SELL) සංඥාවක්' :
            'HOLD — දැන් ගනුදෙනු නොකර බලා සිටීම වඩාත් සුදුසුයි';
    return s + ' · Confidence ' + sig.confidence + '%';
  }

  /* ---------------- Binance helpers ---------------- */

  // decimals from a stepSize string like "0.00100000"
  function stepDecimals(stepStr) {
    if (typeof stepStr !== 'string') return 8;
    var trimmed = stepStr.replace(/0+$/, '');
    var dot = trimmed.indexOf('.');
    if (dot === -1) return 0;
    return trimmed.length - dot - 1;
  }

  function roundQty(qty, stepStr) {
    var step = parseFloat(stepStr);
    if (!step || step <= 0) return qty;
    var d = stepDecimals(stepStr);
    var floored = Math.floor(qty / step) * step;
    return parseFloat(floored.toFixed(Math.min(d, 8)));
  }

  // Build signed query string (params WITHOUT signature)
  function buildQuery(params) {
    var keys = Object.keys(params);
    keys.sort();
    var parts = [];
    for (var i = 0; i < keys.length; i++) {
      parts.push(encodeURIComponent(keys[i]) + '=' + encodeURIComponent(params[keys[i]]));
    }
    return parts.join('&');
  }

  var Engine = {
    SHA256: SHA256,
    hmacSha256Hex: hmacSha256Hex,
    hmacSign: hmacSign,
    sma: sma,
    ema: ema,
    emaSeries: emaSeries,
    rsi: rsi,
    macd: macd,
    bollinger: bollinger,
    atr: atr,
    computeSignal: computeSignal,
    sinhalaSummary: sinhalaSummary,
    roundQty: roundQty,
    stepDecimals: stepDecimals,
    buildQuery: buildQuery
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = Engine;
  }
  root.Engine = Engine;

})(typeof self !== 'undefined' ? self : this);
