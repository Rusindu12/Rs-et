# 🤗 Hugging Face Spaces — RS AI Deploy Guide (පියවරෙන් පියවර)

Colab වගේ නවතින්නේ නැතුව **හැමවෙලේම online** තියෙන free server එකක්.
වියදම **රුපියලක්වත් නෑ** — HF account එක free, CPU Space එක free,
RS AI free smart mode එකත් key නැතුවම වැඩ කරනවා. ✅

> ⏱️ මුළු වැඩේට: විනාඩි ~10 (ඉන් 5–8ක් Space එක build වෙනකන් බලන් ඉන්න එක)

---

## A. HF Account + Space හදන්න (විනාඩි 2)

1. 👉 https://huggingface.co/join — **Sign up** (Google login එකෙන්ම පුළුවන්, free)
2. Login වෙලා ඉවර නම්, උඩ දකුණේ **avatar → New Space** (හරි 👉 https://huggingface.co/new-space)
3. මෙහෙම පුරවන්න:

   | Field | දාන්න ඕන |
   |---|---|
   | Space name | `rs-ai` |
   | License | `mit` |
   | **SDK** | **`Docker`** ⬅️ මේක වැදගත්ම! අනිවා Docker තෝරන්න |
   | Hardware | `CPU basic · FREE` (default) |
   | Visibility | `Public` |
4. **Create Space** ඔබන්න → හිස් Space page එකක් හැදෙනවා 🎉
5. Browser address bar එකේ URL එක බලාගන්න — මේ වගේ:
   `https://huggingface.co/spaces/ඔයාගේ-username/rs-ai`
   (ඔයාගේ-username කෑල්ල මතක තියාගන්න — පහළදි ඕන වෙනවා)

---

## B. RS AI code එක Space එකට දාන්න

විකල්ප 2ක් — ඔයාට ලේසි එක තෝරන්න (දෙකෙන් එකක් ඇති):

### 🖥️ විකල්ප 1: PC එකෙන් (git තියෙනවා නම් — ලේසිම)

PC terminal/command prompt එකේ:

```bash
git clone --depth 1 https://github.com/Rusindu12/Rs-et.git rs-ai-space
cd rs-ai-space
git remote add space https://huggingface.co/spaces/ඔයාගේ-username/rs-ai
git push space main:main
```

* Username/password ඇහුවොත්:
  * username = ඔයාගේ HF username
  * password = **Access Token** එකක් (HF password එක නෙවේ!) —
    👉 https://huggingface.co/settings/tokens → **Create new token** →
    type: **Write** → Generate → copy කරලා paste කරන්න

### 📱 විකල්ප 2: Phone එකෙන්ම (Colab — PC ඕන නෑ)

1. 👉 https://huggingface.co/settings/tokens → **Create new token**
   (name: `rs-ai`, type: **Write**) → token එක **copy** කරගන්න
   (අකුරු ගොඩක් තියෙන `hf_...` code එක — මේක කාටවත් දෙන්න එපා 🔒)
2. 👉 https://colab.research.google.com → **New notebook** → පහළ code එක
   cell එකට paste කරලා ▶️ Run (ඔයාගේ-username + token මාරු කරලා!):

```python
#@title 🚀 Push RS AI to Hugging Face Space
HF_USERNAME = "ඔයාගේ-username"  #@param {type:"string"}
HF_TOKEN = "hf_..."             #@param {type:"string"}

!git clone --depth 1 https://github.com/Rusindu12/Rs-et.git /content/rsai
%cd /content/rsai
!git remote add space https://{HF_USERNAME}:{HF_TOKEN}@huggingface.co/spaces/{HF_USERNAME}/rs-ai
!git push space main:main
print("✅ pushed! දැන් Space page එකේ Building... → Running වෙනකන් බලන් ඉන්න")
```

---

## C. (Optional) Smart mode key + ආරක්ෂාව 🔑

Space page → **Settings → Repository secrets → Add a secret**:

| Secret නම | අගය | මොකටද |
|---|---|---|
| `RS_PROVIDER` | `groq` | free Llama 3.3 70B brain ⚡ |
| `RS_API_KEY` | `gsk_...` | free key: https://console.groq.com |
| `RS_API_TOKEN` | ඔයා හදන password එකක් | අනුන්ට server එක use කරන්න බැරි වෙන්න 🔒 |

> 💡 Secret එකක්වත් නැතුවත් server එක වැඩ කරනවා
> (free key-less smart mode auto-on). `RS_API_TOKEN` දැම්මොත් විතරක්
> app Settings වල **API token** field එකටත් ඒකම දාන්න ඕන.

Secret දැම්මට පස්සේ Space එක **⋯ menu → Restart** කරන්න
(නැත්නම් Factory reboot — secret load වෙන්න restart එකක් ඕන).

---

## D. Build ඉවර වෙනකන් බලන් ඉන්න ⏳

Push කළාට පස්සේ Space page එකේ උඩ:
`Building...` 🟡 → විනාඩි 5–8කින් → **`Running`** 🟢

* 🟢 Running ආවොත්: ඔයාගේ public URL එක ready!
  `https://ඔයාගේ-username-rs-ai.hf.space`
  (Space නමේ තියෙන `-` වෙනුවට `-`මයි; username + spacename `-` වලින් join)
* ඒ URL එක browser එකේ open කළොත් RS AI **web chat UI** එක එනවා 💬
* 🔧 Health check: URL අගට `/diagnose` දාලා බලන්න
  (provider status, latency — live debug page එක)

---

## E. Android app එක connect කරන්න 📱

1. RS AI app → උඩ **⚙️ Settings**
2. Server URL = `https://ඔයාගේ-username-rs-ai.hf.space` → paste
3. `RS_API_TOKEN` දැම්මා නම් → API token field එකටත් ඒක දාන්න
4. **🔗 Test connection** → ✅ Connected! → **Save**
5. ඉවරයි! දැන් හැමවෙලේම chat කරන්න පුළුවන් 🎉
   (Colab වගේ link මාරු වෙන්නේ නෑ — මේ URL එක permanent!)

---

## F. පස්සේ update කරන විදිය 🔄

GitHub repo එක update වුණොත් (අලුත් features):
විකල්ප 1 හරි 2 හරි ආයේ කරලා `git push space main:main` —
Space එක auto-rebuild වෙලා අලුත් version එක run වෙනවා.

---

## ⚠️ ප්‍රශ්නයක් ආවොත්

| ප්‍රශ්නය | විසඳුම |
|---|---|
| Push වල `authentication failed` | password එකට HF login password දාන්න එපා — **Access Token (Write)** එකක් දාන්න |
| Space එක `Build error` / red | Logs බලන්න (Space page → Logs tab) — බොහෝවිට network hiccup එකක්: **⋯ → Factory reboot** |
| App එකේ `Connect fail` | Space එක 🟢 Running ද? URL එක `https://` වලින් පටන්ගන්නවද? අග `/` තියෙනවා නම් අයින් කරන්න |
| `401` error | `RS_API_TOKEN` Space secret එකයි app token field එකයි match වෙන්න ඕන |
| උත්තර හෙමින් / නරකයි | Groq free key එක secrets වල දාන්න (C පියවර) — brain එක ගොඩක් හොඳ වෙනවා ⚡ |
