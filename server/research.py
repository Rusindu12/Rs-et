"""
Deep Research mode for RS AI — 🔬 multi-step web research.

Flow:
  1. external AI generates 3 focused search queries
  2. server searches the web (DuckDuckGo HTML — keyless)
  3. server fetches and cleans the top pages
  4. external AI synthesizes an answer with [1][2] citations + sources list

Needs an external provider (Groq/Gemini/OpenAI...). Falls back gracefully.
"""

import html
import re
from urllib.parse import unquote

import requests

try:  # package mode (uvicorn server.main:app)
    from . import providers
except ImportError:  # script mode (python server/main.py)
    import providers

UA = {"User-Agent": "Mozilla/5.0 (RS-AI research; +https://github.com/Rusindu12/Rs-et)"}
DDG_URL = "https://html.duckduckgo.com/html/"


def ddg_search(query: str, n: int = 6, timeout: int = 20):
    """DuckDuckGo HTML search — returns [{'title':..., 'url':...}]."""
    r = requests.get(DDG_URL, params={"q": query}, headers=UA, timeout=timeout)
    out = []
    for m in re.finditer(r'class="result__a" href="([^"]+)"[^>]*>(.*?)</a>', r.text, re.S):
        url = html.unescape(m.group(1))
        if "uddg=" in url:
            url = unquote(url.split("uddg=", 1)[1].split("&", 1)[0])
        if url.startswith("http"):
            title = re.sub(r"<[^>]+>", "", m.group(2))
            out.append({"title": html.unescape(title).strip(), "url": url})
        if len(out) >= n:
            break
    return out


def fetch_text(url: str, limit: int = 1400, timeout: int = 15) -> str:
    """Fetch a page and strip it to plain text."""
    try:
        r = requests.get(url, headers=UA, timeout=timeout)
        txt = re.sub(r"(?s)<(script|style).*?</\1>", " ", r.text)
        txt = re.sub(r"<[^>]+>", " ", txt)
        txt = re.sub(r"\s+", " ", html.unescape(txt)).strip()
        return txt[:limit]
    except Exception:  # noqa: BLE001 — best effort per source
        return ""


def run_research(chain, question: str, max_sources: int = 5):
    """Returns (reply, sources, provider_name). Raises nothing — caller handles fallback tuple."""
    ext = next((p for p in chain if p.family != "local"), None)
    if ext is None:
        return None, [], "none"

    # 1) search queries
    try:
        qtext = ext.chat(
            f"Generate exactly 3 short web search queries to deeply research this question. "
            f"One query per line, no numbering, no explanations.\nQuestion: {question}",
            max_tokens=120, temperature=0.3,
        )
        queries = [q.strip() for q in qtext.splitlines() if q.strip()][:3] or [question]
    except Exception as e:  # noqa: BLE001
        print(f"[research] query gen failed: {e!r}")
        queries = [question]

    # 2) search + dedupe by domain
    seen, sources = set(), []
    for q in queries:
        try:
            for r in ddg_search(q, n=4):
                dom = re.sub(r"^https?://(www\.)?", "", r["url"]).split("/")[0]
                if dom and dom not in seen:
                    seen.add(dom)
                    sources.append(r)
        except Exception as e:  # noqa: BLE001
            print(f"[research] ddg failed for {q!r}: {e!r}")
        if len(sources) >= max_sources:
            break
    sources = sources[:max_sources]

    if not sources:
        return None, [], ext.name  # no internet / blocked -> caller falls back

    # 3) fetch pages
    blocks = []
    good = []
    for i, s in enumerate(sources):
        txt = fetch_text(s["url"])
        if txt:
            good.append(s)
            blocks.append(f"[{len(good)}] {s['title']} — {s['url']}\n{txt}")

    if not blocks:
        return None, [], ext.name

    # 4) synthesize
    context = "\n\n".join(blocks)
    try:
        reply = ext.chat(
            f"Question: {question}\n\nWEB SOURCES:\n{context}\n\n"
            f"Answer the question thoroughly using these sources with inline citations.",
            max_tokens=900, temperature=0.4,
            system=providers.RESEARCH_PROMPT,
        )
        return reply, good, ext.name
    except Exception as e:  # noqa: BLE001
        print(f"[research] synthesis failed: {e!r}")
        return None, good, ext.name
