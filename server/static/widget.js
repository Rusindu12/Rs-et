/*!
 * RS AI — embeddable chat widget (zero dependencies).
 * Usage:  <script src="https://YOUR_SERVER/static/widget.js"></script>
 * Token:  <script src=".../widget.js" data-token="RS_API_TOKEN"></script>
 * Options: data-mode="chat|think|think_harder|research|image"  data-side="right|left"
 */
(function () {
  var script = document.currentScript;
  var BASE = new URL(script.src).origin;
  var TOKEN = script.dataset.token || '';
  var MODE = script.dataset.mode || 'chat';
  var SYSTEM = script.dataset.system || '';   // optional custom persona
  var chatLog = [];                           // conversation memory turns
  var SIDE = script.dataset.side === 'left' ? 'left' : 'right';

  var css = `
  .rsai-fab{position:fixed;bottom:18px;${SIDE}:18px;width:56px;height:56px;border-radius:50%;
    background:linear-gradient(135deg,#7c3aed,#4f46e5);border:none;color:#fff;font-size:24px;
    cursor:pointer;z-index:999998;box-shadow:0 6px 24px rgba(124,58,237,.45);}
  .rsai-panel{position:fixed;bottom:84px;${SIDE}:16px;width:min(360px,calc(100vw - 32px));
    height:min(500px,calc(100dvh - 120px));background:#0f172a;border:1px solid rgba(148,163,184,.25);
    border-radius:18px;display:none;flex-direction:column;overflow:hidden;z-index:999999;
    font-family:system-ui,'Noto Sans Sinhala',sans-serif;box-shadow:0 12px 40px rgba(0,0,0,.5);}
  .rsai-panel.open{display:flex;}
  .rsai-head{display:flex;align-items:center;gap:10px;padding:12px 14px;
    background:rgba(15,23,42,.9);border-bottom:1px solid rgba(148,163,184,.15);}
  .rsai-head .lg{width:32px;height:32px;border-radius:9px;display:grid;place-items:center;
    background:linear-gradient(135deg,#7c3aed,#4f46e5);font-size:16px;}
  .rsai-head b{color:#e2e8f0;font-size:15px;}
  .rsai-head span{color:#4ade80;font-size:11px;display:block;}
  .rsai-close{margin-left:auto;background:none;border:none;color:#94a3b8;font-size:18px;cursor:pointer;}
  .rsai-msgs{flex:1;overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:8px;}
  .rsai-msg{max-width:85%;padding:9px 13px;border-radius:16px;font-size:14px;line-height:1.5;
    white-space:pre-wrap;word-wrap:break-word;color:#e2e8f0;}
  .rsai-msg.user{align-self:flex-end;background:linear-gradient(135deg,#7c3aed,#4f46e5);color:#fff;
    border-bottom-right-radius:4px;}
  .rsai-msg.bot{align-self:flex-start;background:#1e293b;border:1px solid rgba(148,163,184,.12);
    border-bottom-left-radius:4px;}
  .rsai-msg.bot img{max-width:100%;border-radius:8px;margin-top:6px;}
  .rsai-foot{display:flex;gap:8px;padding:10px;background:rgba(15,23,42,.92);
    border-top:1px solid rgba(148,163,184,.15);}
  .rsai-inp{flex:1;background:#1e293b;border:1px solid rgba(148,163,184,.25);border-radius:999px;
    padding:11px 15px;color:#e2e8f0;font-size:14px;outline:none;}
  .rsai-inp:focus{border-color:#7c3aed;}
  .rsai-send{background:linear-gradient(135deg,#7c3aed,#4f46e5);border:none;color:#fff;width:42px;
    height:42px;border-radius:50%;font-size:16px;cursor:pointer;}
  .rsai-dot{display:inline-block;width:6px;height:6px;border-radius:50%;background:#94a3b8;
    margin-right:3px;animation:rsai-blink 1.2s infinite;}
  @keyframes rsai-blink{0%,60%,100%{opacity:.3}30%{opacity:1}}
  `;

  var style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  var fab = document.createElement('button');
  fab.className = 'rsai-fab';
  fab.textContent = '🤖';
  fab.title = 'RS AI';

  var panel = document.createElement('div');
  panel.className = 'rsai-panel';
  panel.innerHTML =
    '<div class="rsai-head"><div class="lg">🤖</div><div><b>RS AI</b>' +
    '<span>● සබැඳි · Sinhala+English</span></div>' +
    '<button class="rsai-close" title="Close">✕</button></div>' +
    '<div class="rsai-msgs"></div>' +
    '<div class="rsai-foot"><input class="rsai-inp" placeholder="මෙසේජ් එකක් ලියන්න…">' +
    '<button class="rsai-send">➤</button></div>';

  document.body.appendChild(fab);
  document.body.appendChild(panel);

  var msgs = panel.querySelector('.rsai-msgs');
  var inp = panel.querySelector('.rsai-inp');
  var sendBtn = panel.querySelector('.rsai-send');

  function add(text, cls, img) {
    var d = document.createElement('div');
    d.className = 'rsai-msg ' + cls;
    d.textContent = text;
    if (img) {
      var im = document.createElement('img');
      im.src = img; im.loading = 'lazy';
      d.appendChild(document.createElement('br'));
      d.appendChild(im);
    }
    msgs.appendChild(d);
    msgs.scrollTop = msgs.scrollHeight;
  }

  add('ආයුබෝවන්! 👋 මම RS AI — ප්‍රශ්නයක් අහන්න, Sinhala or English.', 'bot');

  function send() {
    var text = inp.value.trim();
    if (!text) return;
    inp.value = '';
    add(text, 'user');
    sendBtn.disabled = true;
    var t = document.createElement('div');
    t.className = 'rsai-msg bot';
    t.innerHTML = '<span class="rsai-dot"></span><span class="rsai-dot"></span><span class="rsai-dot"></span>';
    msgs.appendChild(t);
    msgs.scrollTop = msgs.scrollHeight;
    var headers = { 'Content-Type': 'application/json' };
    if (TOKEN) headers['Authorization'] = 'Bearer ' + TOKEN;
    fetch(BASE + '/chat', {
      method: 'POST',
      headers: headers,
      body: JSON.stringify({
        message: text, mode: MODE,
        history: chatLog.slice(-10),
        system: SYSTEM || undefined
      })
    })
      .then(function (r) {
        if (r.status === 401) throw new Error('API token වැරදියි (data-token)');
        return r.json();
      })
      .then(function (j) {
        t.remove();
        add(j.reply || '…', 'bot', j.image_url || null);
        chatLog.push({ role: 'user', content: text });
        chatLog.push({ role: 'assistant', content: j.reply || '…' });
      })
      .catch(function (e) {
        t.remove();
        add('⚠️ ' + e.message, 'bot');
      })
      .finally(function () { sendBtn.disabled = false; inp.focus(); });
  }

  fab.onclick = function () { panel.classList.toggle('open'); if (panel.classList.contains('open')) inp.focus(); };
  panel.querySelector('.rsai-close').onclick = function () { panel.classList.remove('open'); };
  sendBtn.onclick = send;
  inp.addEventListener('keydown', function (e) { if (e.key === 'Enter') send(); });
})();
