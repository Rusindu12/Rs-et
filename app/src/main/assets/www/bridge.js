/* Bridge between the web UI and the Android native layer.
 * Falls back to browser fetch/localStorage when running outside the APK
 * (useful for previewing in a desktop browser). */
(function () {
  const isNative = typeof window.Native !== 'undefined' && typeof window.Native.platform === 'function';
  const pending = new Map();
  let seq = 0;

  window.__nativeCallback = function (id, res) {
    const p = pending.get(id);
    if (!p) return;
    pending.delete(id);
    if (res.ok) p.resolve(res.body);
    else p.reject(Object.assign(new Error(res.body || ('HTTP ' + res.status)), { status: res.status, body: res.body }));
  };

  function call(fn, ...args) {
    return new Promise((resolve, reject) => {
      const id = 'cb' + (++seq);
      pending.set(id, { resolve, reject });
      try { window.Native[fn](...args, id); } catch (e) { pending.delete(id); reject(e); }
    });
  }

  // Browser fallback storage for keys (INSECURE – dev only)
  const devStore = {
    get: (k) => localStorage.getItem('dev_' + k) || '',
    set: (k, v) => localStorage.setItem('dev_' + k, v)
  };

  async function browserSigned(method, path, query) {
    const key = devStore.get('api_key'), secret = devStore.get('api_secret');
    if (!key || !secret) throw Object.assign(new Error('API keys not configured'), { status: 401 });
    const testnet = devStore.get('testnet') !== 'false';
    const base = testnet ? 'https://testnet.binance.vision' : 'https://api.binance.com';
    const q = (query ? query + '&' : '') + 'recvWindow=10000&timestamp=' + Date.now();
    const enc = new TextEncoder();
    const k = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const sig = Array.from(new Uint8Array(await crypto.subtle.sign('HMAC', k, enc.encode(q)))).map(b => b.toString(16).padStart(2, '0')).join('');
    const signed = q + '&signature=' + sig;
    const opts = { method, headers: { 'X-MBX-APIKEY': key } };
    let url = base + path;
    if (method === 'POST') { opts.body = signed; opts.headers['Content-Type'] = 'application/x-www-form-urlencoded'; }
    else url += '?' + signed;
    const r = await fetch(url, opts);
    const t = await r.text();
    if (!r.ok) throw Object.assign(new Error(t), { status: r.status, body: t });
    return t;
  }

  window.Bridge = {
    isNative,
    toast(msg) {
      if (isNative) Native.toast(msg);
      const el = document.getElementById('toast');
      if (!el) return;
      el.textContent = msg; el.classList.add('show');
      clearTimeout(el._t); el._t = setTimeout(() => el.classList.remove('show'), 2200);
    },
    vibrate(ms) { if (isNative) Native.vibrate(ms); else if (navigator.vibrate) navigator.vibrate(ms); },
    getPref(k) { return isNative ? Native.getPref(k) : (localStorage.getItem('pref_' + k) || ''); },
    setPref(k, v) { if (isNative) Native.setPref(k, String(v)); else localStorage.setItem('pref_' + k, String(v)); },
    saveCredentials(key, secret, testnet) {
      if (isNative) Native.saveCredentials(key, secret, !!testnet);
      else { devStore.set('api_key', key); devStore.set('api_secret', secret); devStore.set('testnet', String(!!testnet)); }
    },
    clearCredentials() {
      if (isNative) Native.clearCredentials();
      else ['api_key', 'api_secret', 'testnet'].forEach(k => localStorage.removeItem('dev_' + k));
    },
    credentialStatus() {
      if (isNative) return JSON.parse(Native.credentialStatus());
      const k = devStore.get('api_key');
      return { hasKeys: !!k && !!devStore.get('api_secret'), apiKeyMasked: k ? k.slice(0, 4) + '••••' + k.slice(-4) : '', testnet: devStore.get('testnet') !== 'false' };
    },
    async getJSON(url) {
      const text = isNative ? await call('httpGet', url) : await (await fetch(url)).text();
      return JSON.parse(text);
    },
    async signed(method, path, query) {
      const text = isNative ? await call('signedRequest', method, path, query || '') : await browserSigned(method, path, query || '');
      return text ? JSON.parse(text) : {};
    }
  };
})();
