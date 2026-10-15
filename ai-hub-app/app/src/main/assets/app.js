/* RS AI Hub — Main App Controller */
'use strict';

/* ── State ──────────────────────────────────────────────────────── */
const $ = (s, ctx) => (ctx || document).querySelector(s);
const $$ = (s, ctx) => [...(ctx || document).querySelectorAll(s)];
let currentView = 'home';
let currentConvIdx = 0;
let currentPersona = 'assistant';
let isStreaming = false;
let currentTool = null;
let lang = localStorage.getItem('rs_ai_hub_lang') || 'en';
const AB = window.AndroidBridge;

/* ── i18n helper ────────────────────────────────────────────────── */
function t(key) { return (window.I18N[lang] && window.I18N[lang][key]) || window.I18N.en[key] || key; }
function applyLang() {
  $$('[data-i]').forEach(el => { el.textContent = t(el.dataset.i); });
  $$('[data-ph]').forEach(el => { el.placeholder = t(el.dataset.ph); });
  $$('[data-title]').forEach(el => { el.title = t(el.dataset.title); });
  document.documentElement.lang = lang;
  // language toggle button
  const lb = $('#langToggle');
  if (lb) lb.textContent = lang === 'en' ? 'සිංහල' : 'EN';
}

/* ── Theme ──────────────────────────────────────────────────────── */
function setTheme(theme) {
  document.documentElement.dataset.theme = theme;
  localStorage.setItem('rs_ai_hub_theme', theme);
  const tb = $('#themeToggle');
  if (tb) tb.innerHTML = theme === 'dark' ? sunIcon() : moonIcon();
}
function initTheme() {
  const saved = localStorage.getItem('rs_ai_hub_theme');
  setTheme(saved || 'dark');
}

/* ── SVG icons (small inline) ───────────────────────────────────── */
const ICONS = {
  home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-4 0a1 1 0 01-1-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 01-1 1h-2z"/></svg>',
  chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>',
  imagine: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>',
  tools: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 000 1.4l1.6 1.6a1 1 0 001.4 0l3.77-3.77a6 6 0 01-7.94 7.94l-6.91 6.91a2.12 2.12 0 01-3-3l6.91-6.91a6 6 0 017.94-7.94l-3.76 3.76z"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 01-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>',
  send: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>',
  stop: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>',
  mic: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z"/><path d="M19 10v2a7 7 0 01-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/></svg>',
  speaker: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M19.07 4.93a10 10 0 010 14.14M15.54 8.46a5 5 0 010 7.07"/></svg>',
  copy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>',
  plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>',
  menu: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></svg>',
  back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>',
  refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 11-2.12-9.36L23 10"/></svg>',
  download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>',
  share: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg>',
  image: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>',
  check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
};
function sunIcon() { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2m0 18v2M4.22 4.22l1.42 1.42m12.72 12.72l1.42 1.42M1 12h2m18 0h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>'; }
function moonIcon() { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg>'; }

/* ── Markdown-lite renderer ─────────────────────────────────────── */
function renderMD(text) {
  if (!text) return '';
  let html = text
    // code blocks (``` ... ```)
    .replace(/```(\w*)\n([\s\S]*?)```/g, (_, lang, code) => `<pre><code class="lang-${lang}">${escHtml(code.trim())}</code></pre>`)
    // inline code
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    // bold
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    // italic
    .replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, '<em>$1</em>')
    // blockquote
    .replace(/^>\s*(.+)$/gm, '<blockquote>$1</blockquote>')
    // unordered list
    .replace(/^[\-\*]\s+(.+)$/gm, '<li>$1</li>')
    // ordered list
    .replace(/^\d+\.\s+(.+)$/gm, '<li>$1</li>')
    // headings
    .replace(/^### (.+)$/gm, '<h4>$1</h4>')
    .replace(/^## (.+)$/gm, '<h3>$1</h3>')
    .replace(/^# (.+)$/gm, '<h2>$1</h2>')
    // line breaks
    .replace(/\n\n/g, '</p><p>')
    .replace(/\n/g, '<br>');
  // wrap in paragraphs
  html = '<p>' + html + '</p>';
  // cleanup
  html = html.replace(/<p><\/p>/g, '').replace(/<p><br>/g, '<p>');
  return html;
}
function escHtml(s) { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

/* ── Toast ──────────────────────────────────────────────────────── */
let toastTimer;
function toast(msg) {
  const el = $('#toast');
  if (!el) return;
  el.textContent = msg;
  el.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('show'), 2200);
}

/* ── Tab navigation ─────────────────────────────────────────────── */
function switchView(name) {
  currentView = name;
  $$('.view').forEach(v => v.classList.toggle('active', v.id === 'view-' + name));
  $$('.tabbar button').forEach(b => b.classList.toggle('active', b.dataset.tab === name));
}

/* ── Textarea auto-resize ───────────────────────────────────────── */
function autoResize(textarea) {
  textarea.style.height = 'auto';
  textarea.style.height = Math.min(textarea.scrollHeight, 120) + 'px';
}

/* ══════════════════════════════════════════════════════════════════
   HOME
   ══════════════════════════════════════════════════════════════════ */
function initHome() {
  // greeting based on time
  const h = new Date().getHours();
  let greetKey = h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  const ge = $('#homeGreet');
  if (ge) ge.textContent = lang === 'si'
    ? (h < 12 ? 'ආයුබෝවන්! ' : h < 18 ? 'සුභ දහවලක්! ' : 'සුභ සන්ධ්‍යාවක්! ') + 'අද මම ඔයාට කොහොමද උදව් කරන්නේ?'
    : (h < 12 ? 'Good morning! ' : h < 18 ? 'Good afternoon! ' : 'Good evening! ') + 'How can I help you today?';

  // ask input → navigate to chat
  const askInput = $('#homeAskInput');
  const askBtn = $('#homeAskBtn');
  if (askInput && askBtn) {
    askBtn.onclick = () => {
      const text = askInput.value.trim();
      if (text) { switchToChatWith(text); askInput.value = ''; }
    };
    askInput.onkeydown = (e) => { if (e.key === 'Enter') askBtn.click(); };
  }
  // quick action items
  $$('.quick-item').forEach(el => {
    el.onclick = () => {
      const action = el.dataset.action;
      if (action === 'chat') switchView('chat');
      else if (action === 'imagine') switchView('imagine');
      else if (action === 'tools') { switchView('tools'); }
      else if (action === 'settings') switchView('settings');
      else { switchView('tools'); selectTool(action); }
    };
  });
}

function switchToChatWith(text) {
  switchView('chat');
  const input = $('#chatInput');
  if (input) { input.value = text; input.focus(); autoResize(input); }
}

/* ══════════════════════════════════════════════════════════════════
   CHAT
   ══════════════════════════════════════════════════════════════════ */
function initChat() {
  ensureConversations();
  renderConvDrawer();
  renderPersonas();
  renderMessages();
  setupComposer();
}

function ensureConversations() {
  let convs = AI.loadConversations();
  if (convs.length === 0) {
    convs = [{ title: t('newChat'), messages: [], persona: 'assistant', created: Date.now() }];
    AI.saveConversations(convs);
  }
  currentConvIdx = Math.min(currentConvIdx, convs.length - 1);
}

function currentConv() {
  const convs = AI.loadConversations();
  return convs[currentConvIdx] || convs[0];
}

function saveCurrentConv(updates) {
  const convs = AI.loadConversations();
  Object.assign(convs[currentConvIdx], updates);
  AI.saveConversations(convs);
}

/* Conversation drawer */
function renderConvDrawer() {
  const list = $('#convList');
  if (!list) return;
  const convs = AI.loadConversations();
  list.innerHTML = convs.map((c, i) =>
    `<div class="conv-item${i === currentConvIdx ? ' active' : ''}" data-idx="${i}">
      <span class="conv-title">${escHtml(c.title || t('newChat'))}</span>
      <button class="conv-del" data-idx="${i}" title="${t('deleteConv')}">✕</button>
    </div>`
  ).join('');
  $$('.conv-item', list).forEach(el => {
    el.onclick = (e) => {
      if (e.target.closest('.conv-del')) return;
      currentConvIdx = +el.dataset.idx;
      renderConvDrawer();
      renderMessages();
      closeConvDrawer();
    };
  });
  $$('.conv-del', list).forEach(btn => {
    btn.onclick = (e) => {
      e.stopPropagation();
      const idx = +btn.dataset.idx;
      const convs = AI.loadConversations();
      if (convs.length <= 1) return;
      convs.splice(idx, 1);
      currentConvIdx = Math.min(currentConvIdx, convs.length - 1);
      AI.saveConversations(convs);
      renderConvDrawer();
      renderMessages();
    };
  });
}
function openConvDrawer() {
  $('#convDrawer').classList.add('open');
  $('#convOverlay').classList.add('open');
}
function closeConvDrawer() {
  $('#convDrawer').classList.remove('open');
  $('#convOverlay').classList.remove('open');
}

/* Personas */
function renderPersonas() {
  const bar = $('#personaBar');
  if (!bar) return;
  const conv = currentConv();
  currentPersona = conv.persona || 'assistant';
  const personas = ['assistant','teacher','coder','writer','translator','chef','mathTutor','bizHelper'];
  const icons = { assistant:'🤖', teacher:'📚', coder:'💻', writer:'✍️', translator:'🌍', chef:'🍳', mathTutor:'🧮', bizHelper:'💼' };
  bar.innerHTML = personas.map(p =>
    `<button class="persona-chip${currentPersona === p ? ' active' : ''}" data-p="${p}">
      ${icons[p]} ${t(p)}
    </button>`
  ).join('');
  $$('.persona-chip', bar).forEach(el => {
    el.onclick = () => {
      currentPersona = el.dataset.p;
      saveCurrentConv({ persona: currentPersona });
      renderPersonas();
    };
  });
}

/* Messages */
function renderMessages() {
  const container = $('#messages');
  if (!container) return;
  const conv = currentConv();
  const msgs = conv.messages || [];
  if (msgs.length === 0) {
    container.innerHTML = `<div class="empty-state"><div class="es-icon">💬</div><p>${t('noMessages')}</p></div>`;
    return;
  }
  container.innerHTML = msgs.map((m, i) => {
    const cls = m.role === 'user' ? 'msg-user' : 'msg-ai';
    const content = m.role === 'user' ? escHtml(m.content) : renderMD(m.content);
    const tools = m.role === 'assistant' ?
      `<div class="msg-tools">
        <button onclick="copyMsg(${i})" title="${t('copy')}">${ICONS.copy} ${t('copy')}</button>
        <button onclick="speakMsg(${i})" title="${t('speakReply')}">${ICONS.speaker}</button>
       </div>` : '';
    return `<div class="msg ${cls}" data-idx="${i}">${content}${tools}</div>`;
  }).join('');
  container.scrollTop = container.scrollHeight;
  // typing indicator
  let ti = $('#typingIndicator');
  if (!ti) {
    ti = document.createElement('div');
    ti.id = 'typingIndicator';
    ti.className = 'typing-indicator';
    ti.innerHTML = '<div class="typing-dot"></div><div class="typing-dot"></div><div class="typing-dot"></div>';
    container.parentElement.appendChild(ti);
  }
}

function appendMessage(role, content) {
  const convs = AI.loadConversations();
  const conv = convs[currentConvIdx];
  if (!conv.messages) conv.messages = [];
  conv.messages.push({ role, content });
  // update title from first user message
  if (role === 'user' && conv.messages.filter(m => m.role === 'user').length === 1) {
    conv.title = content.slice(0, 50) + (content.length > 50 ? '…' : '');
  }
  AI.saveConversations(convs);
  renderMessages();
  renderConvDrawer();
}

function updateLastAI(content) {
  const convs = AI.loadConversations();
  const conv = convs[currentConvIdx];
  const msgs = conv.messages;
  if (msgs.length > 0 && msgs[msgs.length - 1].role === 'assistant') {
    msgs[msgs.length - 1].content = content;
  } else {
    msgs.push({ role: 'assistant', content });
  }
  AI.saveConversations(convs);
  renderMessages();
}

/* Composer */
function setupComposer() {
  const input = $('#chatInput');
  const sendBtn = $('#sendBtn');
  const voiceBtn = $('#voiceBtn');
  const attachBtn = $('#attachBtn');

  if (!input || !sendBtn) return;
  input.oninput = () => autoResize(input);
  input.onkeydown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendBtn.click(); }
  };
  sendBtn.onclick = () => {
    if (isStreaming) { AI.stopGeneration(); isStreaming = false; updateSendBtn(); return; }
    const text = input.value.trim();
    if (!text) return;
    input.value = ''; autoResize(input);
    sendMessage(text);
  };
  if (voiceBtn) {
    voiceBtn.onclick = () => {
      AI.listen(lang === 'si' ? 'si-LK' : 'en-US', (text, err) => {
        if (err === 'unsupported') { toast(t('voiceNotSupported')); return; }
        if (text) { input.value = text; autoResize(input); }
      });
    };
  }
  if (attachBtn) {
    attachBtn.onclick = () => {
      // trigger hidden file input
      const fi = $('#fileInput');
      if (fi) fi.click();
    };
  }
  const fi = $('#fileInput');
  if (fi) {
    fi.onchange = () => {
      const file = fi.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        const dataUrl = reader.result;
        // send vision message with attached image
        sendVisionMessage(input.value.trim() || 'What is in this image?', dataUrl, file.type);
        input.value = ''; autoResize(input);
        fi.value = '';
      };
      reader.readAsDataURL(file);
    };
  }
}

function updateSendBtn() {
  const btn = $('#sendBtn');
  if (!btn) return;
  if (isStreaming) {
    btn.innerHTML = ICONS.stop;
    btn.classList.add('stop');
  } else {
    btn.innerHTML = ICONS.send;
    btn.classList.remove('stop');
  }
}

async function sendMessage(text) {
  appendMessage('user', text);
  await doAIReply();
}

async function sendVisionMessage(text, dataUrl, mime) {
  // append user message with image marker
  const convs = AI.loadConversations();
  const conv = convs[currentConvIdx];
  conv.messages.push({ role: 'user', content: [{ type: 'text', text }, { type: 'image_url', image_url: { url: dataUrl } }] });
  AI.saveConversations(convs);
  renderMessages();
  await doAIReply();
}

async function doAIReply() {
  isStreaming = true;
  updateSendBtn();
  const ti = $('#typingIndicator');
  if (ti) ti.classList.add('show');

  const conv = currentConv();
  const persona = PERSONAS[conv.persona || 'assistant'] || PERSONAS.assistant;
  // build messages array (last 20 for context)
  const msgs = (conv.messages || []).slice(-20).map(m => ({
    role: m.role,
    content: m.content,
  }));

  let fullText = '';
  try {
    fullText = await AI.chat(msgs, {
      system: persona.sys,
      temperature: 0.7,
      maxTokens: 2048,
    }, (delta) => {
      fullText += delta;
      // live update the last AI message in DOM
      updateLastAI(fullText);
    });
    if (!fullText) fullText = t('errorAI');
  } catch (e) {
    const msg = e.message === 'RATE_LIMIT' ? t('rateLimit')
      : e.message && e.message.includes('Network') ? t('networkError')
      : t('errorAI');
    fullText = '⚠️ ' + msg;
  }
  // ensure final content saved
  updateLastAI(fullText);
  isStreaming = false;
  updateSendBtn();
  if (ti) ti.classList.remove('show');
}

/* Copy / Speak individual messages */
window.copyMsg = function(idx) {
  const conv = currentConv();
  const msg = conv.messages && conv.messages[idx];
  if (!msg) return;
  const text = typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content);
  if (navigator.clipboard) navigator.clipboard.writeText(text).then(() => toast(t('copied')));
  else toast(t('copied'));
};
window.speakMsg = function(idx) {
  const conv = currentConv();
  const msg = conv.messages && conv.messages[idx];
  if (!msg) return;
  const text = typeof msg.content === 'string' ? msg.content : '';
  AI.speak(text, lang === 'si' ? 'si-LK' : 'en-US');
};

/* ══════════════════════════════════════════════════════════════════
   IMAGINE
   ══════════════════════════════════════════════════════════════════ */
function initImagine() {
  const genBtn = $('#imagineGenBtn');
  if (!genBtn) return;
  genBtn.onclick = generateImage;
  renderGallery();
}

async function generateImage() {
  const prompt = $('#imaginePrompt').value.trim();
  if (!prompt) return;
  const resultBox = $('#imagineResult');
  const imgEl = $('#imagineImg');
  if (!resultBox || !imgEl) return;

  imgEl.classList.remove('loaded');
  resultBox.innerHTML = '<div class="spinner"></div>';

  const model = $('#imagineModel').value || 'flux';
  const ratio = $('#imagineRatio').value || '1:1';
  const seedVal = $('#imagineSeed').value;
  const enhance = $('#imagineEnhance').checked;

  const [w, h] = ratio.split(':').map(Number);
  const size = 1024;
  const width = w >= h ? size : Math.round(size * w / h);
  const height = h >= w ? size : Math.round(size * h / w);
  const seed = seedVal ? +seedVal : Math.floor(Math.random() * 999999);

  const url = AI.imageUrl(prompt, { width, height, seed, model, enhance });

  const img = new Image();
  img.crossOrigin = 'anonymous';
  img.onload = () => {
    resultBox.innerHTML = '';
    img.style.width = '100%';
    img.style.borderRadius = 'var(--radius-sm)';
    img.style.display = 'block';
    resultBox.appendChild(img);
    const actions = document.createElement('div');
    actions.className = 'img-actions';
    actions.style.cssText = 'position:absolute;bottom:12px;right:12px;display:flex;gap:6px;';
    actions.innerHTML = `
      <button class="btn btn-sm btn-ghost" onclick="downloadImage('${url}')">${ICONS.download}</button>
      <button class="btn btn-sm btn-ghost" onclick="shareImage('${escHtml(prompt)}', '${url}')">${ICONS.share}</button>
    `;
    resultBox.style.position = 'relative';
    resultBox.appendChild(actions);
    // save to gallery
    const gallery = AI.loadGallery();
    gallery.unshift({ url, prompt, seed, model, ratio, ts: Date.now() });
    AI.saveGallery(gallery);
    renderGallery();
  };
  img.onerror = () => {
    resultBox.innerHTML = '<div class="empty-state"><p>⚠️ ' + t('errorAI') + '</p></div>';
  };
  img.src = url;
}

window.downloadImage = function(url) {
  const AB = window.AndroidBridge;
  if (AB && AB.isAndroid()) {
    AB.saveImage(url, '');
    return;
  }
  const a = document.createElement('a');
  a.href = url; a.download = 'RS-AI-Hub-' + Date.now() + '.png';
  document.body.appendChild(a); a.click(); a.remove();
};
window.shareImage = function(prompt, url) {
  const AB = window.AndroidBridge;
  if (AB && AB.isAndroid()) {
    AB.shareText('RS AI Hub — ' + prompt, url);
    return;
  }
  if (navigator.share) navigator.share({ title: 'RS AI Hub', text: prompt, url });
  else if (navigator.clipboard) navigator.clipboard.writeText(url).then(() => toast(t('copied')));
};

function renderGallery() {
  const grid = $('#galleryGrid');
  if (!grid) return;
  const gallery = AI.loadGallery();
  if (gallery.length === 0) {
    grid.innerHTML = `<div class="empty-state" style="grid-column:1/-1"><div class="es-icon">🎨</div><p>${t('noImages')}</p></div>`;
    return;
  }
  grid.innerHTML = gallery.slice(0, 30).map(g =>
    `<div class="gallery-item" onclick="reusePrompt('${escHtml(g.prompt || '').replace(/'/g, "\\'")}')">
      <img src="${g.url}" loading="lazy" alt="AI generated">
    </div>`
  ).join('');
}
window.reusePrompt = function(prompt) {
  switchView('imagine');
  const el = $('#imaginePrompt');
  if (el) { el.value = prompt; el.focus(); }
  window.scrollTo(0, 0);
};

/* ══════════════════════════════════════════════════════════════════
   TOOLS
   ══════════════════════════════════════════════════════════════════ */
function initTools() {
  $$('.tool-card').forEach(el => {
    el.onclick = () => selectTool(el.dataset.tool);
  });
  const goBtn = $('#toolGo');
  if (goBtn) goBtn.onclick = executeTool;
  const backBtn = $('#toolBack');
  if (backBtn) backBtn.onclick = () => { currentTool = null; showToolGrid(); };
  const clearBtn = $('#toolClear');
  if (clearBtn) clearBtn.onclick = () => {
    const ti = $('#toolInput'); if (ti) ti.value = '';
    const to = $('#toolOutput'); if (to) { to.innerHTML = ''; to.dataset.placeholder = t('toolOutput'); }
  };
}

function selectTool(name) {
  currentTool = name;
  hideToolGrid();
  const ws = $('#toolWorkspace');
  if (ws) ws.classList.add('active');
  const title = $('#toolWsTitle');
  if (title) title.textContent = t('tool' + name.charAt(0).toUpperCase() + name.slice(1));
  const langRow = $('#toolLangRow');
  if (langRow) langRow.style.display = name === 'translate' ? 'flex' : 'none';
  const to = $('#toolOutput'); if (to) { to.innerHTML = ''; to.dataset.placeholder = t('toolOutput'); }
  const ti = $('#toolInput'); if (ti) { ti.value = ''; ti.placeholder = t('toolInput'); ti.focus(); }
}

function hideToolGrid() { const g = $('#toolsGrid'); if (g) g.style.display = 'none'; }
function showToolGrid() {
  const g = $('#toolsGrid'); if (g) g.style.display = '';
  const ws = $('#toolWorkspace'); if (ws) ws.classList.remove('active');
}

async function executeTool() {
  if (!currentTool) return;
  const input = $('#toolInput').value.trim();
  if (!input) return;
  const output = $('#toolOutput');
  output.innerHTML = '<div class="spinner"></div>';

  let prompt;
  if (currentTool === 'translate') {
    const from = $('#toolLangFrom').value.trim();
    const to = $('#toolLangTo').value.trim();
    prompt = AI.TOOL_PROMPTS.translate(input, from, to);
  } else {
    prompt = AI.TOOL_PROMPTS[currentTool] ? AI.TOOL_PROMPTS[currentTool](input) : input;
  }

  let full = '';
  try {
    full = await AI.chat([{ role: 'user', content: prompt }], {
      system: AI.SYSTEM_PROMPT,
      temperature: currentTool === 'code' ? 0.2 : 0.7,
      maxTokens: 2048,
    }, (delta) => {
      full += delta;
      output.innerHTML = renderMD(full);
    });
  } catch (e) {
    full = '⚠️ ' + (e.message === 'RATE_LIMIT' ? t('rateLimit') : t('errorAI'));
    output.innerHTML = renderMD(full);
  }
}

/* ══════════════════════════════════════════════════════════════════
   SETTINGS
   ══════════════════════════════════════════════════════════════════ */
function initSettings() {
  const cfg = AI.loadConfig();
  const full = { ...AI.defaultConfig(), ...cfg };

  // Provider selection
  $$('.provider-card').forEach(el => {
    el.onclick = () => selectProvider(el.dataset.provider);
  });
  selectProvider(full.mode || 'free');

  // Provider form values
  const set = (id, val) => { const el = $(id); if (el) el.value = val || ''; };
  set('#customBaseUrl', full.customBaseUrl);
  set('#customKey', full.customKey);
  set('#customModel', full.customModel);
  set('#rsUrl', full.rsUrl);
  set('#rsToken', full.rsToken);

  // Save button
  const saveBtn = $('#settingsSave');
  if (saveBtn) saveBtn.onclick = saveSettings;

  // Test button
  const testBtn = $('#settingsTest');
  if (testBtn) testBtn.onclick = async () => {
    testBtn.textContent = '…';
    const ok = await AI.testConnection();
    testBtn.textContent = ok ? t('testOk') : t('testFail');
    setTimeout(() => { testBtn.textContent = t('testConnection'); }, 3000);
  };
}

function selectProvider(mode) {
  $$('.provider-card').forEach(el => el.classList.toggle('active', el.dataset.provider === mode));
  $$('.provider-form').forEach(el => el.classList.toggle('active', el.id === 'pf-' + mode));
}

function saveSettings() {
  const mode = ($('.provider-card.active') || {}).dataset || {};
  const cfg = {
    mode: mode.provider || 'free',
    customBaseUrl: $('#customBaseUrl').value.trim(),
    customKey: $('#customKey').value.trim(),
    customModel: $('#customModel').value.trim(),
    rsUrl: $('#rsUrl').value.trim(),
    rsToken: $('#rsToken').value.trim(),
  };
  AI.saveConfig(cfg);
  toast(t('saved'));
}

/* ══════════════════════════════════════════════════════════════════
   INIT
   ══════════════════════════════════════════════════════════════════ */
function init() {
  // restore language
  lang = localStorage.getItem('rs_ai_hub_lang') || 'en';
  initTheme();
  applyLang();

  // tab bar
  $$('.tabbar button').forEach(btn => {
    btn.onclick = () => switchView(btn.dataset.tab);
  });

  // drawer toggle
  const menuBtn = $('#menuBtn');
  if (menuBtn) menuBtn.onclick = openConvDrawer;
  const overlay = $('#convOverlay');
  if (overlay) overlay.onclick = closeConvDrawer;
  const newConvBtn = $('#newConvBtn');
  if (newConvBtn) newConvBtn.onclick = () => {
    const convs = AI.loadConversations();
    convs.unshift({ title: t('newChat'), messages: [], persona: 'assistant', created: Date.now() });
    AI.saveConversations(convs);
    currentConvIdx = 0;
    renderConvDrawer();
    renderMessages();
    closeConvDrawer();
  };

  // language toggle
  const langBtn = $('#langToggle');
  if (langBtn) langBtn.onclick = () => {
    lang = lang === 'en' ? 'si' : 'en';
    localStorage.setItem('rs_ai_hub_lang', lang);
    applyLang();
    renderPersonas();
    renderConvDrawer();
  };

  // theme toggle
  const themeBtn = $('#themeToggle');
  if (themeBtn) themeBtn.onclick = () => {
    const cur = document.documentElement.dataset.theme;
    setTheme(cur === 'dark' ? 'light' : 'dark');
  };

  initHome();
  initChat();
  initImagine();
  initTools();
  initSettings();
  switchView('home');
}

document.addEventListener('DOMContentLoaded', init);