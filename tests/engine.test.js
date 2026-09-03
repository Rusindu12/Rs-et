// Engine unit tests — run with: node tests/engine.test.js
const crypto = require('crypto');
const E = require('../app/src/main/assets/js/engine.js');

let pass = 0, fail = 0;
function ok(name, cond, extra) {
  if (cond) { pass++; console.log('  ✓ ' + name); }
  else { fail++; console.log('  ✗ ' + name + (extra ? ' → ' + JSON.stringify(extra) : '')); }
}

console.log('— SHA-256 —');
ok('sha256 "abc"', E.SHA256.hex('abc') === crypto.createHash('sha256').update('abc').digest('hex'));
ok('sha256 ""', E.SHA256.hex('') === crypto.createHash('sha256').update('').digest('hex'));
ok('sha256 long ascii', E.SHA256.hex('The quick brown fox jumps over the lazy dog'.repeat(20)) === crypto.createHash('sha256').update('The quick brown fox jumps over the lazy dog'.repeat(20)).digest('hex'));
ok('sha256 sinhala utf8', E.SHA256.hex('ගනුදෙනු සංඥාව') === crypto.createHash('sha256').update('ගනුදෙනු සංඥාව', 'utf8').digest('hex'));
ok('sha256 binary-ish chars', E.SHA256.hex('Njq7V~mA"Xk#pLz9') === crypto.createHash('sha256').update('Njq7V~mA"Xk#pLz9').digest('hex'));
// exact 55/56/64-byte boundary checks
for (const n of [54, 55, 56, 57, 63, 64, 65, 100, 128]) {
  const s = 'a'.repeat(n);
  ok('sha256 boundary ' + n, E.SHA256.hex(s) === crypto.createHash('sha256').update(s).digest('hex'));
}

console.log('— HMAC-SHA256 —');
const pairs = [
  ['NhqPtmdSJYdKjVHjA7PZj4Mge3R5YNiP1e3UZjInClVN50XT.4w0B6vnBmj4HX', 'symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559'],
  ['verysecret', 'timestamp=1234567890'],
  ['k'.repeat(100), 'x'.repeat(300)],
  ['secret', '']
];
for (const [sec, msg] of pairs) {
  const expect = crypto.createHmac('sha256', sec).update(msg).digest('hex');
  ok('hmac len' + sec.length, E.hmacSha256Hex(sec, msg) === expect, { got: E.hmacSha256Hex(sec, msg), want: expect });
}

console.log('— Indicators —');
// reference data
const closes = [];
let p = 100;
for (let i = 0; i < 300; i++) {
  p += Math.sin(i / 7) * 1.2 + (Math.random() - 0.45) * 0.8;
  closes.push(parseFloat(p.toFixed(6)));
}

// Reference EMA (standard seeding with SMA)
function refEma(vals, period) {
  const k = 2 / (period + 1);
  let prev = vals.slice(0, period).reduce((a, b) => a + b, 0) / period;
  for (let i = period; i < vals.length; i++) prev = vals[i] * k + prev * (1 - k);
  return prev;
}
for (const per of [12, 20, 26, 50, 200]) {
  ok('ema(' + per + ')', Math.abs(E.ema(closes, per) - refEma(closes, per)) < 1e-9);
}

// Reference Wilder RSI
function refRsi(vals, period) {
  let gains = 0, losses = 0;
  for (let i = 1; i <= period; i++) {
    const d = vals[i] - vals[i - 1];
    if (d >= 0) gains += d; else losses -= d;
  }
  let ag = gains / period, al = losses / period;
  for (let j = period + 1; j < vals.length; j++) {
    const d = vals[j] - vals[j - 1];
    ag = (ag * (period - 1) + (d > 0 ? d : 0)) / period;
    al = (al * (period - 1) + (d < 0 ? -d : 0)) / period;
  }
  if (al === 0) return 100;
  return 100 - 100 / (1 + ag / al);
}
ok('rsi(14)', Math.abs(E.rsi(closes, 14) - refRsi(closes, 14)) < 1e-9);

const mac = E.macd(closes);
ok('macd returns object', mac && typeof mac.hist === 'number' && typeof mac.signal === 'number');

const bb = E.bollinger(closes, 20, 2);
ok('bollinger bounds', bb && bb.lower < bb.mid && bb.mid < bb.upper && bb.pctB > -1 && bb.pctB < 2);

// candles + signal
const candles = closes.map((c, i) => ({
  time: 1700000000 + i * 300,
  open: c * 0.999, high: c * 1.004, low: c * 0.995,
  close: c, volume: 100 + Math.sin(i / 5) * 40 + Math.random() * 10
}));
const sig = E.computeSignal(candles);
ok('signal ok', sig.ok === true, sig);
ok('signal score range', sig.score >= -100 && sig.score <= 100);
ok('signal label', ['STRONG BUY', 'BUY', 'HOLD', 'SELL', 'STRONG SELL'].includes(sig.label));
ok('signal confidence', sig.confidence >= 0 && sig.confidence <= 100);
ok('signal has factors', Array.isArray(sig.factors) && sig.factors.length === 6);
ok('sinhala summary string', typeof E.sinhalaSummary(sig) === 'string' && E.sinhalaSummary(sig).length > 5);
const shortSig = E.computeSignal(candles.slice(0, 30));
ok('signal rejects short data', shortSig.ok === false);

// trending-up data should score positive
const up = [];
let q = 50;
for (let i = 0; i < 200; i++) { q *= 1.004; up.push({ time: 1700000000 + i * 300, open: q * 0.999, high: q * 1.002, low: q * 0.998, close: q, volume: 100 }); }
const upSig = E.computeSignal(up);
ok('uptrend scores >= BUY-ish', upSig.score > 15, upSig.score);

const down = [];
let z = 50;
for (let i = 0; i < 200; i++) { z *= 0.996; down.push({ time: 1700000000 + i * 300, open: z * 1.001, high: z * 1.002, low: z * 0.998, close: z, volume: 100 }); }
const downSig = E.computeSignal(down);
ok('downtrend scores negative', downSig.score < -15, downSig.score);

console.log('— Binance qty helpers —');
ok('stepDecimals 0.00100000', E.stepDecimals('0.00100000') === 3);
ok('stepDecimals 1.00000000', E.stepDecimals('1.00000000') === 0);
ok('stepDecimals 0.00001000', E.stepDecimals('0.00001000') === 5);
ok('roundQty 0.001 step', E.roundQty(0.56789, '0.00100000') === 0.567);
ok('roundQty 1 step', E.roundQty(7.9, '1.00000000') === 7);
ok('roundQty tiny step', E.roundQty(123.4567891, '0.00000001') === 123.4567891);
ok('buildQuery sorted', E.buildQuery({ timestamp: 123, symbol: 'BTCUSDT', quantity: 0.01 }) === 'quantity=0.01&symbol=BTCUSDT&timestamp=123');

console.log('\nRESULT: ' + pass + ' passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
