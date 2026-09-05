# RS AI Chat — APK Build Guide (සිංහල)

Android app එක: Kotlin + Jetpack Compose + Retrofit. RS AI server එකට
සම්බන්ධ වෙලා chat කරනවා.

## ⬇️ APK එක කෙලින් download (අලුත් build එකම!)

**👉 [RS-AI.apk — download](https://github.com/Rusindu12/Rs-et/releases/download/apk-latest/RS-AI.apk)**
(Release page: https://github.com/Rusindu12/Rs-et/releases/tag/apk-latest — push එකක් හැමයිම auto-update ✅)

Debug-signed — install කරන්න readyම; "unknown sources" warning එක normal (Play Store එකෙන් නෙවේ නිසා).

<small>Old way: Actions tab → ඕනම successful run එක → **RS-AI-debug-apk** artifact (days 90ට expire).</small>

## විකල්ප 1: Android Studio (පහසුම — විනාඩි 5)

1. [Android Studio](https://developer.android.com/studio) install කරන්න (Hedgehog+).
2. **File → Open** → මේ `android-app/` folder එක open කරන්න.
3. මුල් වතාවට Gradle sync එක dependencies download කරයි (~1 GB, විනාඩි 5-10).
   (Wrapper jar auto-generate වෙයි; "trust" prompt එකට OK කියන්න.)
4. **APK එක හදන්න**:
   - Menu: **Build → Build App Bundle(s) / APK(s) → Build APK(s)**
   - හරි ගියාට පස්සේ "APK(s) generated successfully" → **locate** click කරන්න
   - `android-app/app/build/outputs/apk/debug/app-debug.apk`
5. APK එක phone එකට copy කරලා install කරන්න
   (Settings → "Install unknown apps" allow කරන්න).

## විකල්ප 2: Command line

JDK 17 සහ Android SDK (cmdline-tools, platform-34, build-tools) install වෙලා
`local.properties` එකේ `sdk.dir=/path/to/Android/Sdk` දීලා:

```bash
cd android-app
# මුල් වතාවට wrapper jar එක හදන්න (gradle 8.7 තියෙනවා නම්):
gradle wrapper --gradle-version 8.7
# ඊට පස්සේ හැම වතාවෙම:
./gradlew assembleDebug
# → app/build/outputs/apk/debug/app-debug.apk
```

## Server එක run කරන්න

App එකට කතා කරන්න කලින් RS AI server එක run වෙලා තියෙන්න ඕන:

```bash
cd Rs-et
pip install torch sentencepiece fastapi "uvicorn[standard]" numpy
cd model && mkdir -p tokenizer runs
python tokenizer_train.py --input data/sample_corpus.txt --vocab-size 1600 --model-prefix tokenizer/rs_sp
python train.py --config rs-gpt-demo --data data/sample_corpus.txt --tokenizer tokenizer/rs_sp.model --out-dir runs/demo --steps 450 --batch-size 16
cd ..
python server/main.py     # → http://0.0.0.0:8000
```

## App එකට server URL එක දෙන්න

App එක open කරලා **⚙️ (Settings)** icon එක tap කරලා URL එක දාන්න:

| App එක run වෙන තැන | URL එක |
|---|---|
| Android Emulator | `http://10.0.2.2:8000` |
| Real phone, එකම Wi-Fi එකේ | `http://<PC එකේ IP>:8000` (උදා: `http://192.168.1.5:8000`) |
| Public server / cloud | `https://your-server.com` |

PC එකේ IP එක සොයා ගන්න: Windows → `ipconfig`, Linux/Mac → `ip a`.

සටහන: සිංහලෙන් type කරන්න Gboard හෝ Helakuru keyboard එක install කරගන්න.

## App features 🎛️

- **Mode chips**: 💬 Chat · 💡 Thinking · 🧠 Think harder · 🔬 Deep research · 🎨 Image — server smart mode එකේම වැඩ කරයි
- **📎 Attach**: 📁 files, 🖼️ gallery photos, 📷 camera (photo analyze → smart mode vision)
- **🎙️ Voice input**: සිංහල speech recognizer (RECORD_AUDIO permission අහයි)
- **Real-time streaming** — typewriter effect, long answers ලෝද්න fast ⚡, ⏹ Stop button
- **💾 Chat persistence** — app close/rotate වුණත් chat මතක තියෙනවා (📋 long-press copy)
- **🔊 Voice replies (TTS)** — top bar toggle; Sinhala/English auto-detect
- Research mode answers w/ 📚 clickable sources; image mode generated images bubbles wල
- Server side කිසිම key එකක් නැත්නම් local RS-GPT mode එකෙන් reply — app එක dead වෙන්නේ නෑ
