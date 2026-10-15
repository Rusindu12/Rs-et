/* RS AI Hub — AI Provider Layer (Pollinations free, custom OpenAI-compatible, RS server) */
'use strict';

/* ── Config helpers ──────────────────────────────────────────────── */

const CFG_KEY = 'rs_ai_hub_config';
const CONV_KEY = 'rs_ai_hub_conversations';
const GALLERY_KEY = 'rs_ai_hub_gallery';

function loadConfig() {
  try { return JSON.parse(localStorage.getItem(CFG_KEY)) || {}; } catch (_) { return {}; }
}
function saveConfig(c) { localStorage.setItem(CFG_KEY, JSON.stringify(c)); }

function defaultConfig() {
  return { mode: 'free', model: 'openai', imageModel: 'flux', customBaseUrl: '', customKey: '', customModel: '', rsUrl: '', rsToken: '' };
}

/* ── Provider: chat (streaming + fallback) ───────────────────────── */

/**
 * Send messages to the AI and stream the response.
 * @param {Array<{role:string,content:string|Array}>} messages - full conversation
 * @param {object} opts - { system, temperature, maxTokens }
 * @param {function} onDelta - called with each text chunk
 * @returns {Promise<string>} full text
 */
async function aiChat(messages, opts = {}, onDelta = null) {
  const cfg = { ...defaultConfig(), ...loadConfig() };
  const system = opts.system || null;
  const temperature = opts.temperature ?? 0.7;
  const maxTokens = opts.maxTokens || 1024;

  // build the message array with system prompt
  const msgs = [];
  if (system) msgs.push({ role: 'system', content: system });
  msgs.push(...messages);

  if (cfg.mode === 'custom') {
    return await chatOpenAICompatible(cfg.customBaseUrl, cfg.customKey, cfg.customModel || 'gpt-4o-mini', msgs, { temperature, maxTokens }, onDelta);
  }
  if (cfg.mode === 'rs') {
    const url = cfg.rsUrl.replace(/\/+$/, '') + '/v1/chat/completions';
    const headers = { 'Content-Type': 'application/json' };
    if (cfg.rsToken) headers['Authorization'] = 'Bearer ' + cfg.rsToken;
    return await chatGeneric(url, headers, cfg.model || 'openai', msgs, { temperature, maxTokens }, onDelta);
  }

  // FREE mode: try streaming first, then fallbacks
  return await chatFreeChain(msgs, cfg.model || 'openai', { temperature, maxTokens }, onDelta);
}

async function chatOpenAICompatible(baseUrl, key, model, msgs, opts, onDelta) {
  const url = baseUrl.replace(/\/+$/, '') + '/chat/completions';
  const headers = { 'Content-Type': 'application/json' };
  if (key) headers['Authorization'] = 'Bearer ' + key;
  return await chatGeneric(url, headers, model, msgs, opts, onDelta);
}

async function chatGeneric(url, headers, model, msgs, { temperature, maxTokens }, onDelta) {
  const body = { model, messages: msgs, temperature, max_tokens: maxTokens, stream: !!onDelta };

  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
    signal: onDelta ? undefined : undefined,
  });

  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    if (res.status === 429) throw new Error('RATE_LIMIT');
    throw new Error(`API ${res.status}: ${txt.slice(0, 200)}`);
  }

  if (onDelta && res.body) return await readSSE(res.body, onDelta);
  // non-streaming
  const data = await res.json();
  return (data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content) || '';
}

async function chatFreeChain(msgs, model, opts, onDelta) {
  // Strategy: POST /openai (stream) → POST / (stream) → POST /openai (non-stream) → GET /text
  const errors = [];

  // 1. POST /openai with stream
  if (onDelta) {
    try {
      return await chatGeneric('https://text.pollinations.ai/openai',
        { 'Content-Type': 'application/json' }, model, msgs, { ...opts, maxTokens: opts.maxTokens }, onDelta);
    } catch (e) { errors.push(e); }
  }

  // 2. POST /openai non-stream
  try {
    return await chatGeneric('https://text.pollinations.ai/openai',
      { 'Content-Type': 'application/json' }, model, msgs, { ...opts, maxTokens: opts.maxTokens }, null);
  } catch (e) { errors.push(e); }

  // 3. POST / root endpoint
  try {
    return await chatGeneric('https://text.pollinations.ai/',
      { 'Content-Type': 'application/json' }, model, msgs, { ...opts, maxTokens: opts.maxTokens }, null);
  } catch (e) { errors.push(e); }

  // 4. GET fallback
  try {
    const flat = msgs.map(m => (m.role === 'user' || !m.role) ? m.content : '').filter(Boolean).join('\n');
    const url = 'https://text.pollinations.ai/' + encodeURIComponent(flat) + '?model=' + encodeURIComponent(model);
    const res = await fetch(url);
    if (!res.ok) throw new Error('GET fallback ' + res.status);
    const text = await res.text();
    if (onDelta) onDelta(text);
    return text;
  } catch (e) { errors.push(e); }

  const last = errors[errors.length - 1];
  throw last instanceof Error ? last : new Error(String(last));
}

/* ── SSE reader ──────────────────────────────────────────────────── */

async function readSSE(body, onDelta) {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let full = '';
  let cancelled = false;

  const wrap = {
    cancel() { cancelled = true; try { reader.cancel(); } catch (_) {} }
  };
  window._currentSSE = wrap;

  try {
    while (!cancelled) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';
      for (const line of lines) {
        if (!line.startsWith('data: ')) continue;
        const payload = line.slice(6).trim();
        if (payload === '[DONE]') { cancelled = true; break; }
        try {
          const obj = JSON.parse(payload);
          const delta = obj.choices && obj.choices[0] && obj.choices[0].delta;
          if (delta && delta.content) {
            full += delta.content;
            onDelta(delta.content);
          }
        } catch (_) { /* ignore malformed chunks */ }
      }
    }
  } catch (e) {
    if (!cancelled) throw e;
  }
  return full;
}

function stopGeneration() {
  if (window._currentSSE) { window._currentSSE.cancel(); window._currentSSE = null; }
}

/* ── Image generation ────────────────────────────────────────────── */

function aiImageUrl(prompt, opts = {}) {
  const cfg = { ...defaultConfig(), ...loadConfig() };
  const width = opts.width || 1024;
  const height = opts.height || 1024;
  const seed = opts.seed || Math.floor(Math.random() * 999999);
  const model = opts.model || cfg.imageModel || 'flux';
  const enhance = opts.enhance !== false;
  const p = encodeURIComponent(prompt);
  let url = `https://image.pollinations.ai/prompt/${p}?width=${width}&height=${height}&seed=${seed}&nologo=true&model=${model}`;
  if (enhance) url += '&enhance=true';
  return url;
}

/* ── TTS (free via Pollinations audio) ───────────────────────────── */

function aiSpeak(text, lang) {
  const AB = window.AndroidBridge;
  if (AB && AB.isAndroid()) {
    AB.speak(text, lang || '');
    return;
  }
  // browser fallback
  if ('speechSynthesis' in window) {
    const u = new SpeechSynthesisUtterance(text);
    if (lang) u.lang = lang;
    speechSynthesis.speak(u);
  }
}

function aiStopSpeak() {
  const AB = window.AndroidBridge;
  if (AB && AB.isAndroid()) { AB.stopSpeak(); return; }
  if ('speechSynthesis' in window) speechSynthesis.cancel();
}

/* ── Voice input ─────────────────────────────────────────────────── */

function aiListen(lang, onResult) {
  window.onVoiceResult = function(text, err) {
    window.onVoiceResult = null;
    if (onResult) onResult(text || '', err);
  };
  const AB = window.AndroidBridge;
  if (AB && AB.isAndroid()) {
    AB.listen(lang || 'si-LK');
    return;
  }
  // browser fallback (webkitSpeechRecognition)
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) {
    if (onResult) onResult('', 'unsupported');
    return;
  }
  const r = new SR();
  r.lang = lang || 'si-LK';
  r.interimResults = false;
  r.maxAlternatives = 1;
  r.onresult = (e) => { if (onResult) onResult(e.results[0][0].transcript || ''); };
  r.onerror = (e) => { if (onResult) onResult('', e.error); };
  r.onend = () => {};
  try { r.start(); } catch (e) { if (onResult) onResult('', 'start_failed'); }
}

/* ── Conversation persistence ────────────────────────────────────── */

function loadConversations() {
  try { return JSON.parse(localStorage.getItem(CONV_KEY)) || []; } catch (_) { return []; }
}
function saveConversations(list) { localStorage.setItem(CONV_KEY, JSON.stringify(list)); }

function loadGallery() {
  try { return JSON.parse(localStorage.getItem(GALLERY_KEY)) || []; } catch (_) { return []; }
}
function saveGallery(list) { localStorage.setItem(GALLERY_KEY, JSON.stringify(list.slice(0, 100))); } // cap at 100

/* ── Test connection ─────────────────────────────────────────────── */

async function aiTestConnection() {
  const cfg = { ...defaultConfig(), ...loadConfig() };
  try {
    let url, headers;
    if (cfg.mode === 'custom') {
      url = cfg.customBaseUrl.replace(/\/+$/, '') + '/models';
      headers = {};
      if (cfg.customKey) headers['Authorization'] = 'Bearer ' + cfg.customKey;
    } else if (cfg.mode === 'rs') {
      url = cfg.rsUrl.replace(/\/+$/, '') + '/health';
      headers = {};
      if (cfg.rsToken) headers['Authorization'] = 'Bearer ' + cfg.rsToken;
    } else {
      url = 'https://text.pollinations.ai/models';
      headers = {};
    }
    const res = await fetch(url, { headers, signal: AbortSignal.timeout(10000) });
    return res.ok;
  } catch (_) {
    return false;
  }
}

/* ── System prompts ──────────────────────────────────────────────── */

const SYSTEM_PROMPT = "You are RS AI Hub, a friendly all-in-one AI assistant created by the RS team from Sri Lanka. You are fluent in Sinhala and English. Always reply in the SAME language the user uses — Sinhala questions get Sinhala answers. Be concise, warm and helpful. For code, use proper formatting. For math, show step-by-step work.";

const PERSONAS = {
  assistant: { sys: SYSTEM_PROMPT },
  teacher: { sys: SYSTEM_PROMPT + " You are a patient, inspiring teacher. Explain concepts simply with examples, analogies, and step-by-step reasoning. Use visuals/emojis when helpful. Adapt to the student's level." },
  coder: { sys: SYSTEM_PROMPT + " You are an expert software engineer. Write clean, well-commented code in whatever language is requested. Explain your approach before the code. For debugging, identify the root cause first, then provide a fix. Always include error handling." },
  writer: { sys: SYSTEM_PROMPT + " You are a talented creative writer and editor. Help with stories, poems, essays, blog posts, and any writing task. Improve drafts for clarity, style, grammar, and impact. Be creative and expressive." },
  translator: { sys: SYSTEM_PROMPT + " You are a professional translator. Translate accurately while preserving tone, idioms, and cultural nuance. If the source and target languages aren't specified, ask. For Sinhala-English, use natural phrasing, not word-for-word." },
  chef: { sys: SYSTEM_PROMPT + " You are a skilled chef and food expert. Provide detailed recipes with ingredients, steps, cooking times, and tips. Suggest Sri Lankan and international dishes. Include substitutions for dietary restrictions." },
  mathTutor: { sys: SYSTEM_PROMPT + " You are a math tutor. Solve problems step-by-step with clear explanations. Show each step's reasoning. Check your answers. Use LaTeX-style formatting when helpful (use \\( \\) for inline and \\[ \\] for display math)." },
  bizHelper: { sys: SYSTEM_PROMPT + " You are a business and marketing strategist. Help with business plans, marketing strategies, social media content, startup advice, financial analysis, and professional communication. Be practical and actionable." },
};

/* ── Tool prompts ────────────────────────────────────────────────── */

const TOOL_PROMPTS = {
  translate: (text, from, to) => `Translate the following ${from ? 'from ' + from : ''} ${to ? 'to ' + to : 'to the other major language'}. Only output the translation, nothing else.\n\nText:\n${text}`,
  summarize: (text) => `Summarize the following text concisely, highlighting the key points. Use bullet points if appropriate.\n\nText:\n${text}`,
  rewrite: (text) => `Rewrite the following text to improve clarity, style, and flow while preserving the original meaning. Make it more professional and engaging.\n\nText:\n${text}`,
  grammar: (text) => `Fix all spelling and grammar errors in the following text. Then list the changes you made briefly. Output the corrected text first.\n\nText:\n${text}`,
  email: (text) => `Write a professional, well-structured email based on the following instructions. Include subject line, greeting, body, and sign-off.\n\nInstructions:\n${text}`,
  code: (text) => `${text}`,
  homework: (text) => `Help with this homework / study question. Provide a clear, step-by-step explanation. Show your reasoning at each step.\n\nQuestion:\n${text}`,
  study: (text) => `Create organized, clear study notes on the following topic. Use headings, bullet points, key terms, and summaries. Make it easy to revise from.\n\nTopic:\n${text}`,
  story: (text) => `${text}`,
};

/* ── Export ───────────────────────────────────────────────────────── */

window.AI = {
  chat: aiChat,
  imageUrl: aiImageUrl,
  speak: aiSpeak,
  stopSpeak: aiStopSpeak,
  listen: aiListen,
  testConnection: aiTestConnection,
  stopGeneration,
  loadConfig, saveConfig, defaultConfig,
  loadConversations, saveConversations,
  loadGallery, saveGallery,
  SYSTEM_PROMPT, PERSONAS, TOOL_PROMPTS,
};