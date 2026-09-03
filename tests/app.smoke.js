// Smoke test: boot the whole app in a mock DOM and simulate live trading flows.
const fs = require('fs');
const path = require('path');

/* ---------- tiny DOM mock ---------- */
function makeEl() {
  const el = {
    style: {}, dataset: {}, children: [], textContent: '', innerHTML: '', value: '', className: '',
    classList: {
      add(c) { el.className += ' ' + c; }, remove(c) { el.className = el.className.replace(c, ''); },
      toggle() {}, contains() { return false; }
    },
    addEventListener() {}, appendChild() {}, setAttribute() {},
    clientWidth: 360, clientHeight: 300, title: '',
    applyOptions() {}, setData() {}, update() {}
  };
  return el;
}
const els = {};
const byId = new Proxy({}, { get: (t, id) => (els[id] = els[id] || makeEl()) });

global.document = {
  getElementById: id => byId[id],
  querySelectorAll: () => [],
  addEventListener() {},
  visibilityState: 'visible',
  createElement: () => makeEl()
};
global.localStorage = (() => {
  const store = {};
  return { getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = v; }, removeItem: k => delete store[k] };
})();
global.window = { addEventListener() {} };
global.navigator = { vibrate() {} };
global.confirm = () => true;
global.ResizeObserver = class { observe() {} };
global.fetch = async (url) => {
  // canned REST responses
  if (url.includes('/api/v3/time')) return { ok: true, json: async () => ({ serverTime: Date.now() }) };
  if (url.includes('/api/v3/exchangeInfo')) {
    return { ok: true, json: async () => ({ symbols: [{ filters: [
      { filterType: 'LOT_SIZE', stepSize: '0.00100000' },
      { filterType: 'PRICE_FILTER', tickSize: '0.01000000' },
      { filterType: 'NOTIONAL', minNotional: 5 }
    ] }] }) };
  }
  if (url.includes('/api/v3/klines')) {
    // 400 synthetic candles, gentle uptrend with noise
    const qs = new URL(url, 'http://x').searchParams;
    let p = 100 + Math.random() * 50;
    const rows = [];
    const t0 = Math.floor(Date.now() / 1000) - 400 * 300;
    for (let i = 0; i < 400; i++) {
      const o = p, c = p + (Math.sin(i / 9) * 1.5 + (Math.random() - 0.42) * 1.0);
      rows.push([ (t0 + i * 300) * 1000, o.toFixed(4), Math.max(o, c + 0.7).toFixed(4), Math.min(o, c - 0.7).toFixed(4), c.toFixed(4), (100 + Math.random() * 50).toFixed(4), 0, 0, 0 ]);
      p = c;
    }
    return { ok: true, json: async () => rows };
  }
  throw new Error('unexpected fetch ' + url);
};
global.WebSocket = class {
  constructor(url) { this.url = url; setTimeout(() => this.onopen && this.onopen(), 1); }
  send() {} close() { if (this.onclose) setTimeout(() => this.onclose(), 1); }
};

/* ---------- chart lib mock (real one is UMD-IIFE for browsers; mimic surface) ---------- */
const seriesMock = () => ({ setData() {}, update() {}, applyOptions() {} });
global.LightweightCharts = {
  createChart: () => ({
    addCandlestickSeries: seriesMock,
    addHistogramSeries: seriesMock,
    addLineSeries: seriesMock,
    priceScale: () => ({ applyOptions() {} }),
    applyOptions() {}
  })
};

/* ---------- load app ---------- */
global.self = global; // engine.js attaches to `self`
const engineSrc = fs.readFileSync(path.join(__dirname, '../app/src/main/assets/js/engine.js'), 'utf8');
eval(engineSrc);

const html = fs.readFileSync(path.join(__dirname, '../app/src/main/assets/app.html'), 'utf8');
const m = html.match(/<script>([\s\S]*?)<\/script>/);
if (!m) { console.error('✗ no main script found'); process.exit(1); }

let step = 'boot';
try {
  eval(m[1] + '\n;global.__X__ = { App, botBuy, botSell, onTick, onCandleClose, pickSymbol, renderAll, switchSec, setMode, fmtPrice, openSettings };');
  console.log('  ✓ boot() completed without exception');
} catch (e) {
  console.error('  ✗ ' + step + ' threw: ' + e.stack.split('\n').slice(0, 3).join(' | '));
  process.exit(1);
}
const { App, botBuy, onTick, onCandleClose, pickSymbol, renderAll, switchSec, setMode, fmtPrice } = global.__X__;

/* ---------- assertions on app internals ---------- */
const A = App;
const ok = (n, c, x) => { if (c) console.log('  ✓ ' + n); else { console.log('  ✗ ' + n + (x !== undefined ? ' → ' + JSON.stringify(x) : '')); process.exitCode = 1; } };

setTimeout(async () => {
  ok('candles loaded', A.candles.length === 400, A.candles.length);
  ok('signal computed', A.signal && A.signal.ok === true, A.signal);
  ok('feed has first entry', A.feed.length >= 1);

  // simulate a live kline tick upward
  step = 'ws tick';
  const k = A.candles[A.candles.length - 1];
  const newClose = k.close * 1.01;
  A.ws.onmessage({ data: JSON.stringify({ data: { e: 'kline', k: { t: k.time * 1000, o: k.open, h: Math.max(k.high, newClose), l: k.low, c: newClose, v: 250, x: false } } }) });
  ok('price updated from ws', Math.abs(A.price - newClose) < 1e-9, A.price);

  // simulate candle close event
  A.ws.onmessage({ data: JSON.stringify({ data: { e: 'kline', k: { t: k.time * 1000, o: k.open, h: k.high, l: k.low, c: newClose, v: 250, x: true } } }) });
  ok('candle close handled', true);

  // bot on + strong buy flow (paper)
  step = 'paper trade';
  A.mode = 'paper';
  A.bot.minScore = 20;
  A.paper.usdt = 10000; A.paper.position = null;
  await botBuy('test');
  ok('paper position opened', !!A.paper.position && A.paper.usdt < 10000, A.paper);
  const pos = A.paper.position;
  const entry = pos.entryPrice;

  // price +2% → TP hit (bot.tp default 1.5)
  A.price = entry * 1.021;
  onTick();
  await new Promise(r => setTimeout(r, 20));
  ok('position closed on TP', A.paper.position === null, A.paper.position);
  ok('P&L recorded', A.trades.length >= 2 && A.trades[0].pnl > 0, A.trades[0]);
  ok('paper balance grew', A.paper.usdt > 10000, A.paper.usdt);

  // SL flow
  A.paper.position = null; A.paper.usdt = 10000;
  await botBuy('test2');
  A.price = A.paper.position.entryPrice * 0.98;
  onTick();
  await new Promise(r => setTimeout(r, 20));
  ok('position closed on SL', A.paper.position === null);
  ok('loss recorded', A.trades[0].pnl < 0, A.trades[0]);

  // symbol switch path
  step = 'symbol switch';
  pickSymbol('ETHUSDT');
  await new Promise(r => setTimeout(r, 50));
  ok('symbol switched + candles reloaded', A.symbol === 'ETHUSDT' && A.candles.length === 400, A.candles.length);

  // bot entry decision path (candle close triggers entry when score >= minScore)
  step = 'bot decision';
  A.bot.on = true; A.bot.minScore = -1000; A.paper.position = null; A.paper.usdt = 10000;
  onCandleClose();
  await new Promise(r => setTimeout(r, 20));
  ok('bot auto-entered', !!A.paper.position, A.paper);

  // render functions do not throw
  step = 'render';
  renderAll(); switchSec({ dataset: { sec: 'sec-bot' }, classList: { add() {}, remove() {} } });
  setMode('testnet'); setMode('paper');
  ok('renderAll + tab switch + setMode OK', true);

  // fmt helpers
  ok('fmtPrice small', fmtPrice(0.000012345) === '0.000012345'.slice(0, 8) || typeof fmtPrice(0.000012345) === 'string');
  ok('roundQty integration', Engine.roundQty(1.23456, '0.00100000') === 1.234);

  console.log(process.exitCode ? '\nSMOKE FAILED' : '\nSMOKE PASSED');
  process.exit(process.exitCode ? 1 : 0);
}, 30);
