/* Binance AI Trader – main application logic */
(function () {
  const $ = (id) => document.getElementById(id);
  const REST = 'https://api.binance.com';
  const WS = 'wss://stream.binance.com:9443/stream?streams=';
  const DEFAULT_WATCH = ['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT', 'XRPUSDT', 'DOGEUSDT', 'ADAUSDT'];

  const state = {
    symbol: Bridge.getPref('symbol') || 'BTCUSDT',
    interval: Bridge.getPref('interval') || '5m',
    mode: Bridge.getPref('mode') || 'paper',       // paper | testnet | live
    watch: (Bridge.getPref('watch') || DEFAULT_WATCH.join(',')).split(',').map(s => s.trim().toUpperCase()).filter(Boolean),
    candles: [],
    lastPrice: 0,
    prevPrice: 0,
    ticker: null,
    analysis: null,
    ws: null,
    wsRetry: 0,
    bot: Bridge.getPref('bot') === 'true',
    lastBotTrade: 0,
    symbolInfo: {},        // symbol -> { stepSize, tickSize, minNotional }
    paper: loadPaper()
  };

  /* ---------------- Paper trading store ---------------- */
  function loadPaper() {
    try { return JSON.parse(Bridge.getPref('paper') || '') || null; } catch (e) { return null; }
  }
  function defaultPaper() { return { balance: 10000, realized: 0, positions: [], history: [] }; }
  if (!state.paper) state.paper = defaultPaper();
  function savePaper() { Bridge.setPref('paper', JSON.stringify(state.paper)); }

  /* ---------------- UI helpers ---------------- */
  const fmt = (n, d) => n == null || isNaN(n) ? '—' : Number(n).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
  const fmtPrice = (p) => p >= 1000 ? fmt(p, 2) : p >= 1 ? fmt(p, 4) : fmt(p, 6);
  const fmtVol = (v) => v >= 1e9 ? (v / 1e9).toFixed(2) + 'B' : v >= 1e6 ? (v / 1e6).toFixed(2) + 'M' : v >= 1e3 ? (v / 1e3).toFixed(1) + 'K' : fmt(v, 0);

  function setConn(status, text) {
    const el = $('connStatus');
    el.className = 'conn ' + status;
    el.querySelector('span:last-child').textContent = text;
  }

  function renderModeBadge() {
    const b = $('modeBadge');
    b.textContent = state.mode.toUpperCase();
    b.className = 'sub ' + state.mode;
    document.querySelectorAll('#modeSeg button').forEach(x => x.classList.toggle('on', x.dataset.mode === state.mode));
    $('botHint').textContent = state.mode === 'paper' ? 'Simulated orders on STRONG signals' : `Real ${state.mode} orders on STRONG signals`;
  }

  function renderSymbols() {
    const sel = $('symbolSelect');
    sel.innerHTML = state.watch.map(s => `<option value="${s}" ${s === state.symbol ? 'selected' : ''}>${s.replace('USDT', '/USDT')}</option>`).join('');
    $('intervalSelect').value = state.interval;
    $('watchlist').value = state.watch.join(', ');
  }

  function renderTicker() {
    const t = state.ticker; if (!t) return;
    const p = state.lastPrice;
    const el = $('lastPrice');
    el.textContent = fmtPrice(p);
    el.className = 'price ' + (p >= state.prevPrice ? 'up' : 'down');
    const ch = parseFloat(t.P);
    const c = $('priceChange');
    c.textContent = (ch >= 0 ? '+' : '') + ch.toFixed(2) + '%';
    c.className = 'change ' + (ch >= 0 ? 'up' : 'down');
    $('high24').textContent = fmtPrice(parseFloat(t.h));
    $('low24').textContent = fmtPrice(parseFloat(t.l));
    $('vol24').textContent = fmtVol(parseFloat(t.q)) + ' USDT';
  }

  function renderAnalysis() {
    const a = state.analysis; if (!a) return;
    const sig = $('aiSignal');
    sig.textContent = a.signal;
    sig.className = 'ai-signal ' + (a.score >= 30 ? 'buy' : a.score <= -30 ? 'sell' : 'hold');
    $('aiConf').textContent = `Confidence ${a.confidence}% · Score ${a.score > 0 ? '+' : ''}${a.score}`;
    const bar = $('aiBar');
    const w = Math.abs(a.score) / 2;
    bar.className = a.score >= 0 ? 'buy' : 'sell';
    bar.style.width = w + '%';
    bar.style.left = a.score >= 0 ? '50%' : (50 - w) + '%';
    $('aiReasons').innerHTML = a.reasons.map(r => `<li>${r}</li>`).join('');
    const ind = a.ind || {};
    const setInd = (id, text, cls) => { const e = $(id); e.textContent = text; e.className = cls || ''; };
    setInd('indRsi', fmt(ind.rsi, 1), ind.rsi < 30 ? 'up' : ind.rsi > 70 ? 'down' : '');
    setInd('indMacd', ind.macdHist == null ? '—' : (ind.macdHist > 0 ? '▲ ' : '▼ ') + Math.abs(ind.macdHist).toPrecision(3), ind.macdHist > 0 ? 'up' : 'down');
    setInd('indEma', ind.ema9 == null ? '—' : (ind.ema9 > ind.ema21 ? 'Bullish' : 'Bearish'), ind.ema9 > ind.ema21 ? 'up' : 'down');
    setInd('indBb', fmt(ind.pctB, 2), ind.pctB < 0.2 ? 'up' : ind.pctB > 0.8 ? 'down' : '');
    setInd('indVol', fmt(ind.volRatio, 2) + '×', ind.volRatio > 1.3 ? 'up' : '');
    setInd('indTrend', ind.trend || '—', /up/i.test(ind.trend || '') ? 'up' : /down/i.test(ind.trend || '') ? 'down' : '');
  }

  /* ---------------- Chart (canvas candlesticks) ---------------- */
  function drawChart() {
    const cv = $('chart');
    const dpr = window.devicePixelRatio || 1;
    const W = cv.clientWidth, H = cv.clientHeight;
    if (cv.width !== W * dpr) { cv.width = W * dpr; cv.height = H * dpr; }
    const ctx = cv.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);
    const all = state.candles;
    const N = Math.min(80, all.length);
    if (N < 2) { ctx.fillStyle = '#848E9C'; ctx.font = '13px sans-serif'; ctx.fillText('Loading chart…', 12, 24); return; }
    const data = all.slice(-N);
    const off = all.length - N;
    const padR = 58, padT = 10, padB = 34;
    const volH = 40;
    const cw = (W - padR) / N;
    let min = Infinity, max = -Infinity, vmax = 0;
    const s = state.analysis && state.analysis.series;
    data.forEach((c, k) => {
      min = Math.min(min, c.l); max = Math.max(max, c.h); vmax = Math.max(vmax, c.v);
      if (s && s.bb.lower[off + k] != null) { min = Math.min(min, s.bb.lower[off + k]); max = Math.max(max, s.bb.upper[off + k]); }
    });
    const range = max - min || 1;
    const y = (p) => padT + (1 - (p - min) / range) * (H - padT - padB - volH);
    const x = (k) => k * cw + cw / 2;

    // grid + price labels
    ctx.strokeStyle = '#1E2329'; ctx.lineWidth = 1; ctx.fillStyle = '#848E9C'; ctx.font = '10px sans-serif'; ctx.textAlign = 'left';
    for (let g = 0; g <= 4; g++) {
      const p = min + range * g / 4, yy = y(p);
      ctx.beginPath(); ctx.moveTo(0, yy); ctx.lineTo(W - padR, yy); ctx.stroke();
      ctx.fillText(fmtPrice(p), W - padR + 4, yy + 3);
    }

    // Bollinger band fill
    if (s) {
      ctx.beginPath(); let started = false;
      data.forEach((c, k) => { const u = s.bb.upper[off + k]; if (u == null) return; if (!started) { ctx.moveTo(x(k), y(u)); started = true; } else ctx.lineTo(x(k), y(u)); });
      for (let k = N - 1; k >= 0; k--) { const l = s.bb.lower[off + k]; if (l != null) ctx.lineTo(x(k), y(l)); }
      ctx.closePath(); ctx.fillStyle = 'rgba(255,255,255,0.04)'; ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,0.18)'; ctx.stroke();
    }

    // volume
    data.forEach((c, k) => {
      const h = (c.v / (vmax || 1)) * volH;
      ctx.fillStyle = c.c >= c.o ? 'rgba(14,203,129,.35)' : 'rgba(246,70,93,.35)';
      ctx.fillRect(x(k) - cw * 0.35, H - padB - h, cw * 0.7, h);
    });

    // candles
    data.forEach((c, k) => {
      const up = c.c >= c.o;
      ctx.strokeStyle = ctx.fillStyle = up ? '#0ECB81' : '#F6465D';
      ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(x(k), y(c.h)); ctx.lineTo(x(k), y(c.l)); ctx.stroke();
      const top = y(Math.max(c.o, c.c)), bh = Math.max(1, Math.abs(y(c.o) - y(c.c)));
      ctx.fillRect(x(k) - cw * 0.35, top, cw * 0.7, bh);
    });

    // EMAs
    const line = (arr, color) => {
      ctx.beginPath(); ctx.strokeStyle = color; ctx.lineWidth = 1.5; let st = false;
      data.forEach((c, k) => { const v = arr[off + k]; if (v == null) return; if (!st) { ctx.moveTo(x(k), y(v)); st = true; } else ctx.lineTo(x(k), y(v)); });
      ctx.stroke();
    };
    if (s) { line(s.ema9, '#F0B90B'); line(s.ema21, '#8A5CF6'); }

    // last price line
    const lp = data[N - 1].c, ly = y(lp);
    ctx.setLineDash([3, 3]); ctx.strokeStyle = '#F0B90B'; ctx.beginPath(); ctx.moveTo(0, ly); ctx.lineTo(W - padR, ly); ctx.stroke(); ctx.setLineDash([]);
    ctx.fillStyle = '#F0B90B'; ctx.fillRect(W - padR, ly - 8, padR, 16);
    ctx.fillStyle = '#0B0E11'; ctx.font = 'bold 10px sans-serif'; ctx.fillText(fmtPrice(lp), W - padR + 4, ly + 3);

    // time labels
    ctx.fillStyle = '#848E9C'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    for (let k = 0; k < N; k += Math.ceil(N / 5)) {
      const d = new Date(data[k].t);
      const lbl = state.interval.endsWith('d') ? `${d.getMonth() + 1}/${d.getDate()}` : `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
      ctx.fillText(lbl, x(k), H - 4);
    }
  }

  /* ---------------- Market data ---------------- */
  async function loadHistory() {
    setConn('', 'loading…');
    try {
      const raw = await Bridge.getJSON(`${REST}/api/v3/klines?symbol=${state.symbol}&interval=${state.interval}&limit=200`);
      state.candles = raw.map(k => ({ t: k[0], o: +k[1], h: +k[2], l: +k[3], c: +k[4], v: +k[5] }));
      const t = await Bridge.getJSON(`${REST}/api/v3/ticker/24hr?symbol=${state.symbol}`);
      state.ticker = t; state.prevPrice = state.lastPrice = +t.c;
      recompute(); renderTicker();
    } catch (e) {
      setConn('err', 'REST error');
      Bridge.toast('Failed to load market data: ' + (e.message || e));
    }
  }

  function connectWS() {
    if (state.ws) { try { state.ws.onclose = null; state.ws.close(); } catch (e) { } }
    const sym = state.symbol.toLowerCase();
    const streams = [`${sym}@kline_${state.interval}`, `${sym}@miniTicker`, `${sym}@ticker`].join('/');
    const ws = new WebSocket(WS + streams);
    state.ws = ws;
    ws.onopen = () => { state.wsRetry = 0; setConn('ok', 'live'); };
    ws.onclose = () => {
      setConn('err', 'reconnecting…');
      const delay = Math.min(15000, 1000 * Math.pow(2, state.wsRetry++));
      setTimeout(() => { if (state.ws === ws) connectWS(); }, delay);
    };
    ws.onerror = () => setConn('err', 'ws error');
    ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data);
      const d = msg.data; if (!d) return;
      if (d.e === 'kline') {
        const k = d.k;
        const c = { t: k.t, o: +k.o, h: +k.h, l: +k.l, c: +k.c, v: +k.v };
        const last = state.candles[state.candles.length - 1];
        if (last && last.t === c.t) state.candles[state.candles.length - 1] = c;
        else if (!last || c.t > last.t) { state.candles.push(c); if (state.candles.length > 500) state.candles.shift(); }
        state.prevPrice = state.lastPrice; state.lastPrice = c.c;
        recompute();
        if (k.x) botTick(true);
      } else if (d.e === '24hrTicker') {
        state.ticker = d; renderTicker();
      } else if (d.e === '24hrMiniTicker') {
        state.prevPrice = state.lastPrice; state.lastPrice = +d.c; renderTicker(); checkPaperExits();
      }
    };
  }

  let recomputeTimer = null;
  function recompute() {
    if (recomputeTimer) return;
    recomputeTimer = setTimeout(() => {
      recomputeTimer = null;
      state.analysis = TA.analyze(state.candles);
      renderAnalysis(); drawChart(); renderTicker();
    }, 80);
  }

  async function loadExchangeInfo() {
    try {
      const info = await Bridge.getJSON(`${REST}/api/v3/exchangeInfo?symbols=${encodeURIComponent(JSON.stringify(state.watch))}`);
      info.symbols.forEach(s => {
        const lot = s.filters.find(f => f.filterType === 'LOT_SIZE') || {};
        const pf = s.filters.find(f => f.filterType === 'PRICE_FILTER') || {};
        const nt = s.filters.find(f => f.filterType === 'NOTIONAL' || f.filterType === 'MIN_NOTIONAL') || {};
        state.symbolInfo[s.symbol] = { stepSize: +lot.stepSize || 0.00001, tickSize: +pf.tickSize || 0.01, minNotional: +(nt.minNotional) || 5 };
      });
    } catch (e) { /* fall back to defaults */ }
  }

  function roundStep(qty, step) {
    const dec = Math.max(0, Math.round(-Math.log10(step)));
    return (Math.floor(qty / step) * step).toFixed(dec);
  }

  /* ---------------- Trading ---------------- */
  function settings() {
    return {
      size: Math.max(5, +$('orderSize').value || 50),
      minConf: +$('minConf').value || 70,
      tp: (+$('tpPct').value || 1.5) / 100,
      sl: (+$('slPct').value || 0.8) / 100
    };
  }

  async function placeOrder(side, reason) {
    const s = settings();
    const price = state.lastPrice;
    if (!price) return Bridge.toast('No price yet');
    const info = state.symbolInfo[state.symbol] || { stepSize: 0.00001, minNotional: 5 };
    const qty = roundStep(s.size / price, info.stepSize);
    if (+qty * price < info.minNotional) return Bridge.toast(`Order below min notional (${info.minNotional} USDT)`);

    if (state.mode === 'paper') return paperOrder(side, +qty, price, reason);

    const cred = Bridge.credentialStatus();
    if (!cred.hasKeys) { Bridge.toast('Add API keys in Settings first'); return showView('settings'); }
    if (state.mode === 'live' && !confirm(`LIVE ${side} ${qty} ${state.symbol} (~${s.size} USDT) with REAL funds?`)) return;
    try {
      const q = `symbol=${state.symbol}&side=${side}&type=MARKET&quantity=${qty}`;
      const res = await Bridge.signed('POST', '/api/v3/order', q);
      const fill = res.fills && res.fills.length ? res.fills.reduce((a, f) => a + +f.price * +f.qty, 0) / res.fills.reduce((a, f) => a + +f.qty, 0) : price;
      addHistory({ side, qty: +qty, price: fill, symbol: state.symbol, reason, mode: state.mode, orderId: res.orderId, time: Date.now() });
      if (side === 'BUY') {
        state.paper.positions.push({ id: res.orderId, symbol: state.symbol, qty: +qty, entry: fill, tp: fill * (1 + s.tp), sl: fill * (1 - s.sl), time: Date.now(), mode: state.mode });
        savePaper();
      }
      Bridge.vibrate(40);
      Bridge.toast(`${state.mode.toUpperCase()} ${side} filled @ ${fmtPrice(fill)}`);
      renderPortfolio(); refreshAccount();
    } catch (e) {
      let msg = e.message;
      try { msg = JSON.parse(e.body).msg || msg; } catch (_) { }
      Bridge.toast('Order failed: ' + msg);
    }
  }

  function paperOrder(side, qty, price, reason) {
    const p = state.paper, s = settings();
    if (side === 'BUY') {
      const cost = qty * price;
      if (cost > p.balance) return Bridge.toast('Insufficient paper balance');
      p.balance -= cost;
      p.positions.push({ id: Date.now(), symbol: state.symbol, qty, entry: price, tp: price * (1 + s.tp), sl: price * (1 - s.sl), time: Date.now(), mode: 'paper' });
      addHistory({ side, qty, price, symbol: state.symbol, reason, mode: 'paper', time: Date.now() });
      Bridge.toast(`Paper BUY ${qty} ${state.symbol} @ ${fmtPrice(price)}`);
    } else {
      const pos = p.positions.filter(x => x.symbol === state.symbol);
      if (!pos.length) return Bridge.toast('No paper position to sell');
      pos.forEach(x => closePosition(x.id, price, reason || 'Manual sell'));
    }
    Bridge.vibrate(30);
    savePaper(); renderPortfolio();
  }

  async function closePosition(id, price, reason) {
    const p = state.paper;
    const idx = p.positions.findIndex(x => x.id === id);
    if (idx < 0) return;
    const pos = p.positions[idx];
    price = price || (pos.symbol === state.symbol ? state.lastPrice : pos.entry);
    if (pos.mode !== 'paper') {
      // real exit order
      try {
        const info = state.symbolInfo[pos.symbol] || { stepSize: 0.00001 };
        const q = `symbol=${pos.symbol}&side=SELL&type=MARKET&quantity=${roundStep(pos.qty, info.stepSize)}`;
        const res = await Bridge.signed('POST', '/api/v3/order', q);
        if (res.fills && res.fills.length) price = res.fills.reduce((a, f) => a + +f.price * +f.qty, 0) / res.fills.reduce((a, f) => a + +f.qty, 0);
      } catch (e) { let msg = e.message; try { msg = JSON.parse(e.body).msg || msg; } catch (_) { } return Bridge.toast('Close failed: ' + msg); }
    }
    const pnl = (price - pos.entry) * pos.qty;
    if (pos.mode === 'paper') p.balance += pos.qty * price;
    p.realized += pnl;
    p.positions.splice(idx, 1);
    addHistory({ side: 'SELL', qty: pos.qty, price, symbol: pos.symbol, reason, pnl, mode: pos.mode, time: Date.now() });
    Bridge.toast(`Closed ${pos.symbol} PnL ${pnl >= 0 ? '+' : ''}${pnl.toFixed(2)} USDT`);
    Bridge.vibrate(pnl >= 0 ? 30 : 80);
    savePaper(); renderPortfolio();
  }

  function addHistory(h) { state.paper.history.unshift(h); if (state.paper.history.length > 200) state.paper.history.pop(); savePaper(); }

  function checkPaperExits() {
    const price = state.lastPrice; if (!price) return;
    state.paper.positions.filter(x => x.symbol === state.symbol).forEach(x => {
      if (price >= x.tp) closePosition(x.id, price, 'Take profit hit');
      else if (price <= x.sl) closePosition(x.id, price, 'Stop loss hit');
    });
  }

  function botTick(candleClosed) {
    if (!state.bot || !state.analysis || !candleClosed) return;
    const a = state.analysis, s = settings();
    if (Date.now() - state.lastBotTrade < 60000) return;
    const hasPos = state.paper.positions.some(x => x.symbol === state.symbol);
    if (a.signal === 'STRONG BUY' && a.confidence >= s.minConf && !hasPos) {
      state.lastBotTrade = Date.now();
      placeOrder('BUY', `Bot: ${a.signal} (${a.confidence}%)`);
    } else if ((a.signal === 'STRONG SELL' || a.signal === 'SELL') && a.confidence >= s.minConf && hasPos) {
      state.lastBotTrade = Date.now();
      state.paper.positions.filter(x => x.symbol === state.symbol).forEach(x => closePosition(x.id, state.lastPrice, `Bot: ${a.signal} (${a.confidence}%)`));
    }
  }

  /* ---------------- Portfolio ---------------- */
  let accountBalances = null;
  async function refreshAccount() {
    if (state.mode === 'paper' || !Bridge.credentialStatus().hasKeys) { accountBalances = null; return renderPortfolio(); }
    try {
      const acc = await Bridge.signed('GET', '/api/v3/account', '');
      accountBalances = acc.balances.filter(b => +b.free + +b.locked > 0);
      renderPortfolio();
    } catch (e) { let msg = e.message; try { msg = JSON.parse(e.body).msg || msg; } catch (_) { } Bridge.toast('Account: ' + msg); }
  }

  function renderPortfolio() {
    const p = state.paper;
    let unreal = 0, posValue = 0;
    p.positions.forEach(x => { const px = x.symbol === state.symbol ? state.lastPrice : x.entry; unreal += (px - x.entry) * x.qty; posValue += px * x.qty; });
    let equityText;
    if (state.mode === 'paper') equityText = '$' + fmt(p.balance + posValue, 2);
    else if (accountBalances) { const u = accountBalances.find(b => b.asset === 'USDT'); equityText = (u ? fmt(+u.free + +u.locked, 2) : '0.00') + ' USDT'; }
    else equityText = '—';
    $('pfEquity').textContent = equityText;
    $('pfRealized').textContent = (p.realized >= 0 ? '+' : '') + '$' + fmt(p.realized, 2);
    $('pfRealized').style.color = p.realized >= 0 ? '#0ECB81' : '#F6465D';
    $('pfUnrealized').textContent = (unreal >= 0 ? '+' : '') + '$' + fmt(unreal, 2);
    $('pfUnrealized').style.color = unreal >= 0 ? '#0ECB81' : '#F6465D';

    const posEl = $('positions');
    const rows = [];
    p.positions.forEach(x => {
      const px = x.symbol === state.symbol ? state.lastPrice : x.entry;
      const pnl = (px - x.entry) * x.qty, pct = (px / x.entry - 1) * 100;
      rows.push(`<div class="item"><div class="l"><b>${x.symbol} <span class="tag buy">${x.mode}</span></b><small>${x.qty} @ ${fmtPrice(x.entry)} · TP ${fmtPrice(x.tp)} · SL ${fmtPrice(x.sl)}</small></div>
        <div class="r ${pnl >= 0 ? 'up' : 'down'}">${pnl >= 0 ? '+' : ''}${pnl.toFixed(2)}<br><small>${pct.toFixed(2)}%</small></div>
        <button class="close" data-close="${x.id}">Close</button></div>`);
    });
    if (accountBalances) accountBalances.forEach(b => rows.push(`<div class="item"><div class="l"><b>${b.asset}</b><small>wallet balance</small></div><div class="r">${fmt(+b.free, 6)}<br><small>locked ${fmt(+b.locked, 4)}</small></div></div>`));
    posEl.innerHTML = rows.length ? rows.join('') : '<div class="empty">No open positions</div>';
    posEl.querySelectorAll('[data-close]').forEach(b => b.onclick = () => closePosition(+b.dataset.close || b.dataset.close, null, 'Manual close'));

    $('history').innerHTML = p.history.length ? p.history.slice(0, 50).map(h => {
      const d = new Date(h.time);
      return `<div class="item"><div class="l"><b><span class="tag ${h.side.toLowerCase()}">${h.side}</span> ${h.symbol}</b><small>${h.qty} @ ${fmtPrice(h.price)} · ${h.reason || ''}</small><small>${d.toLocaleString()}</small></div>
        <div class="r ${h.pnl == null ? '' : h.pnl >= 0 ? 'up' : 'down'}">${h.pnl == null ? '' : (h.pnl >= 0 ? '+' : '') + h.pnl.toFixed(2)}</div></div>`;
    }).join('') : '<div class="empty">No trades yet</div>';
  }

  /* ---------------- Navigation & settings ---------------- */
  function showView(name) {
    document.querySelectorAll('.view').forEach(v => v.classList.toggle('active', v.id === 'view-' + name));
    document.querySelectorAll('.tabbar button').forEach(b => b.classList.toggle('on', b.dataset.view === name));
    if (name === 'portfolio') { renderPortfolio(); refreshAccount(); }
    if (name === 'market') setTimeout(drawChart, 50);
    if (name === 'settings') renderKeyStatus();
  }
  window.__onBack = function () {
    const active = document.querySelector('.view.active');
    if (active && active.id !== 'view-market') { showView('market'); return true; }
    return false;
  };

  function renderKeyStatus() {
    const c = Bridge.credentialStatus();
    $('keyStatus').textContent = c.hasKeys ? `Saved: ${c.apiKeyMasked} (${c.testnet ? 'testnet' : 'live'} keys)` : 'No keys saved';
  }

  function switchSymbol(sym, interval) {
    state.symbol = sym; state.interval = interval || state.interval;
    Bridge.setPref('symbol', state.symbol); Bridge.setPref('interval', state.interval);
    state.candles = []; state.analysis = null; drawChart();
    loadHistory().then(connectWS);
  }

  function bind() {
    $('symbolSelect').onchange = (e) => switchSymbol(e.target.value);
    $('intervalSelect').onchange = (e) => switchSymbol(state.symbol, e.target.value);
    $('btnBuy').onclick = () => placeOrder('BUY', 'Manual buy');
    $('btnSell').onclick = () => placeOrder('SELL', 'Manual sell');
    $('botToggle').checked = state.bot;
    $('botToggle').onchange = (e) => {
      state.bot = e.target.checked; Bridge.setPref('bot', state.bot);
      if (state.bot && state.mode !== 'paper' && !Bridge.credentialStatus().hasKeys) { Bridge.toast('Add API keys first'); state.bot = false; e.target.checked = false; }
      Bridge.toast(state.bot ? 'Auto-trade bot ON' : 'Auto-trade bot OFF');
    };
    ['orderSize', 'minConf', 'tpPct', 'slPct'].forEach(id => {
      const saved = Bridge.getPref(id); if (saved) $(id).value = saved;
      $(id).onchange = () => Bridge.setPref(id, $(id).value);
    });
    document.querySelectorAll('.tabbar button').forEach(b => b.onclick = () => showView(b.dataset.view));
    document.querySelectorAll('#modeSeg button').forEach(b => b.onclick = () => {
      const m = b.dataset.mode;
      if (m === 'live' && !confirm('Live mode places REAL orders with REAL money. Continue?')) return;
      state.mode = m; Bridge.setPref('mode', m); renderModeBadge(); refreshAccount();
      const c = Bridge.credentialStatus();
      if (m !== 'paper' && c.hasKeys && c.testnet !== (m === 'testnet')) Bridge.toast(`Saved keys are for ${c.testnet ? 'testnet' : 'live'} — re-save keys for ${m}`);
    });
    $('btnSaveKeys').onclick = () => {
      const k = $('apiKey').value.trim(), s = $('apiSecret').value.trim();
      if (!k || !s) return Bridge.toast('Enter both key and secret');
      Bridge.saveCredentials(k, s, state.mode !== 'live');
      $('apiKey').value = ''; $('apiSecret').value = '';
      renderKeyStatus(); Bridge.toast('Keys saved securely'); refreshAccount();
    };
    $('btnClearKeys').onclick = () => { Bridge.clearCredentials(); renderKeyStatus(); Bridge.toast('Keys cleared'); };
    $('btnSaveWatch').onclick = () => {
      const list = $('watchlist').value.split(/[\s,]+/).map(s => s.trim().toUpperCase()).filter(Boolean);
      if (!list.length) return;
      state.watch = list; Bridge.setPref('watch', list.join(','));
      if (!list.includes(state.symbol)) state.symbol = list[0];
      renderSymbols(); loadExchangeInfo(); switchSymbol(state.symbol);
      Bridge.toast('Watchlist saved');
    };
    $('btnResetPaper').onclick = () => { if (confirm('Reset paper balance to 10,000 USDT and clear history?')) { state.paper = defaultPaper(); savePaper(); renderPortfolio(); } };
    $('btnRefreshAcc').onclick = refreshAccount;
    window.addEventListener('resize', drawChart);
    document.addEventListener('visibilitychange', () => { if (!document.hidden && state.ws && state.ws.readyState !== 1) connectWS(); });
  }

  /* ---------------- Boot ---------------- */
  function boot() {
    renderModeBadge(); renderSymbols(); bind(); renderPortfolio(); renderKeyStatus();
    loadExchangeInfo();
    loadHistory().then(connectWS);
    refreshAccount();
  }
  boot();
})();
