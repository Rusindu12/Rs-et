# EduMate AI — Flutter App (සිංහල setup guide)

EduMate AI කියන්නේ ශ්‍රී ලංකාවේ Grade 1–13 සිසුන් සඳහා Sinhala-first study companion app එකක්. මේ repository එකේ `edumate_flutter/` තුළ Flutter source එකත්, `../edumate_backend/` තුළ FastAPI backend එකත් ඇත. App එක **demo/offline mode** එකෙන් Firebase හෝ AI server එකක් නැතිවම open කරලා UI එක බලන්න පුළුවන්.

> **සටහන:** මෙය ක්‍රියාකාරී MVP / foundation එකක්. සියලුම පාඩම් සඳහා සම්පූර්ණ නිල Sri Lankan syllabus content සහ past-paper PDFs seed කර නැහැ. Bundled lessons/quiz ප්‍රදර්ශන සඳහා පමණයි; පාසල් සිසුන්ට publish කිරීමට පෙර ගුරුවරයෙකුගෙන් content එක සත්‍යාපනය කරන්න.

## 1. අවශ්‍ය දේ

- Flutter 3.27+ stable + Dart 3.6 හෝ ඉහළ
- Android Studio / Android SDK / JDK 17
- Android Emulator හෝ Android phone
- (විකල්ප) Firebase project
- (විකල්ප) `edumate_backend` සඳහා Python 3.11+

## 2. Android project එක සකසා run කරන්න

මෙම repo එකේ Flutter app source (`pubspec.yaml`, `lib/`) ඇත. ඔබේ Flutter SDK එකෙන් Android platform scaffolding එක generate කරගන්න:

```bash
cd edumate_flutter
flutter create --platforms android .
flutter pub get
flutter run
```

App එක open වුණාම **Explore demo mode** තෝරන්න. එවිට login credentials නැතිව Home, grade/subject/chapter navigation, demo quiz, profile සහ settings භාවිතා කළ හැකියි.

APK එක build කිරීම:

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

`flutter_pdfview`, ML Kit, speech recognition සහ Firebase plugins Android native build එකටත් සම්බන්ධ වන නිසා, APK හදන පළමු වතාවේ Gradle dependencies download වීමට කාලයක් ගතවෙන්න පුළුවන්. Repository checkout එකේ Flutter SDK නැති නිසා මෙහි APK binary එක build කර නැහැ.

## 3. Firebase Authentication / Firestore / Storage සකසන්න

1. Firebase Console එකේ project එකක් සාදන්න. Android app එක add කරන විට `android/app/build.gradle(.kts)` හි generated `applicationId` එකම භාවිතා කරන්න (උදා: `com.example.edumate_ai`; project එකේ application id වෙනස් කළොත් ඒ අලුත් id එක භාවිතා කරන්න).
2. Email/Password provider එක enable කරන්න; අවශ්‍ය නම් Google provider එකත් enable කර SHA-1/SHA-256 fingerprints එක් කරන්න.
3. `google-services.json` ගොනුව `edumate_flutter/android/app/` වෙත දාන්න.
4. `android/settings.gradle` සහ `android/app/build.gradle` තුළ Google Services Gradle plugin-ийг Firebase Android setup guide අනුව enable කරන්න.
5. `flutter run` නැවත කරන්න. `Firebase.initializeApp()` native Firebase config-ийг කියවයි. `google-services.json` නැතිනම් app එක local demo mode එකට fallback වේ.
6. `android/app/src/main/AndroidManifest.xml` තුළ camera සහ voice input සඳහා `<uses-permission android:name="android.permission.CAMERA" />` සහ `<uses-permission android:name="android.permission.RECORD_AUDIO" />` එක් කරන්න (plugins වල permission guidance එකත් පරීක්ෂා කරන්න).
7. Firestore Rules සඳහා `../edumate_backend/firestore.rules.example` භාවිතා කර ඔබගේ project එකට review කර deploy කරන්න.

`google-services.json`-හි Firebase web/API identifiers තිබීම AI provider key එකක් APK එකට දැමීමක් නොවේ. නමුත් Firestore/Storage security rules අනිවාර්යයි. Production app එකක AI model secret/token එකක් **Flutter client එකට කිසිවිටෙක දාන්න එපා**.

### Firestore syllabus document shape

Flutter repository එක මේ read path භාවිතා කරයි:

```text
grades/{gradeId}/subjects/{subjectId}/chapters/{chapterId}
```

Document fields උදාහරණය:

```json
{
  "order": 1,
  "titleEn": "Numbers and operations",
  "titleSi": "සංඛ්‍යා හා ගණිත ක්‍රියා",
  "summaryEn": "Number patterns and operations",
  "summarySi": "සංඛ්‍යා රටා හා ක්‍රියා",
  "content": {
    "notes": ["Teacher-reviewed note 1", "Worked example ..."],
    "videoUrl": "https://...",
    "notesPdfUrl": "https://..."
  }
}
```

මෙම implementation එක `content` chapter document එකේ map field එකක් ලෙස තබයි. Firestore path එකේ collection/document segments මාරුවෙන් යන නිසා `content` subcollection එකක් නම් `content/{contentId}` වැනි document එකක් අවශ්‍ය වේ; subcollection තෝරන්නේ නම් Flutter query එක ඒ path එකට වෙනස් කරන්න. Past papers `grades/{gradeId}/subjects/{subjectId}/papers/{paperId}` යටතේ `year`, `title`, `markingScheme`, `pdfUrl` fields වලින් කියවයි. PDF ගොනු Firebase Storage වෙත upload කර HTTPS download URL එක Firestore එකට දාන්න.

Student data paths:

```text
users/{uid}
users/{uid}/chat_sessions/{contextKey}
users/{uid}/quiz_history/{resultId}
```

## 4. FastAPI backend එක run කරන්න

```bash
cd edumate_backend
python -m venv .venv
# Linux/macOS:
source .venv/bin/activate
# Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Health check: `http://127.0.0.1:8000/api/health` · API docs: `/docs`.

**Model hosting:** FastAPI එක Llama weights ඇතුළත් කරන්නේ නැහැ; ඒ වෙනුවට self-host කළ OpenAI-compatible chat-completions endpoint එකට context-aware requests forward කරනවා. `.env` තුළ `LLM_ENDPOINT` (සම්පූර්ණ `/v1/chat/completions` URL) සහ model id එක දාන්න. Endpoint එක token එකක් ඉල්ලන්නේ නම් `LLM_API_KEY` backend `.env` / Render secret එකේ පමණක් තබන්න. Flutter app එකට AI API key එකක් යන්නේ නැහැ.

```dotenv
LLM_ENDPOINT=https://your-model-space.example/v1/chat/completions
LLM_MODEL=meta-llama/Llama-3.2-3B-Instruct
LLM_API_KEY=
```

`LLM_ENDPOINT` නැතිව backend run කළොත් API එක health/PDF endpoints ලබා දෙනවා; chat එක පැහැදිලි `not_configured` preview පිළිතුරක් දෙනවා. Chat request එකේ grade + A/L stream + subject + chapter context යනවා. `latest/current/today/අලුත්ම/අද` වගේ කාල-සංවේදී වචන තිබුණොත් optional DuckDuckGo search එකක් trigger වෙලා sources chat UI එකේ පෙන්වනවා. Search failure එකෙන් chat එක crash වෙන්නේ නැහැ.

### Render deploy (backend)

Render Web Service එකක් create කර:

- **Root directory:** `edumate_backend`
- **Build command:** `pip install -r requirements.txt`
- **Start command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`
- **Health check path:** `/api/health`
- Environment secrets: `LLM_ENDPOINT`, optional `LLM_API_KEY`, `LLM_MODEL`, `CORS_ORIGINS`

Android app එකේ Profile → **AI backend URL** වෙත Render HTTPS URL එක දාන්න.

> Render free services sleep/cold-start, CPU/memory සහ runtime සීමාවලට යටත්. Hugging Face Spaces free hardware එකේ 3B model එක නිතරම වේගයෙන්/විශ්වාසදායකව run වේ යැයි සහතික කළ නොහැක; Llama model access/license terms, RAM, cold start සහ host quotas පරීක්ෂා කරන්න. “100% free / unlimited” hosting එකක් සහතිකයක් නොවේ. ගාස්තු ඇති API එකක් භාවිතා කළ යුතු නොවේ—self-hosted endpoint එකක් පමණක් backend එකට සකසන්න.

### Hugging Face model Space (විකල්ප self-hosted inference)

`../edumate_model_space/README.md` තුළ Docker Space එක deploy කරන starter code ඇත. Space එකේ `HF_TOKEN` අවශ්‍ය වන්නේ gated Llama weights download කිරීමට පමණක් වන අතර host secret එකක් ලෙස තබයි; public open model එකකට token නැතිවද deploy කළ හැකියි. අවශ්‍ය නම් model server එකේ `INFERENCE_BEARER_TOKEN` සහ FastAPI backend එකේ `LLM_API_KEY` එකම secret අගයට සකසන්න. දෙකම backend/host අතර පමණයි—APK එකට නැහැ. Free CPU Space එකේ 3B model එකේ memory, speed, license, sleep/cold-start සහ quota සීමා අනිවාර්යයෙන් පරීක්ෂා කරන්න.

## 5. Android device එකෙන් backend වෙත connect වීම

Profile → AI backend URL:

| App run කරන තැන | URL |
|---|---|
| Android Emulator | `http://10.0.2.2:8000` |
| Same Wi-Fi phone | `http://<computer-LAN-IP>:8000` |
| Deployed backend | `https://your-service.onrender.com` |

Public use සඳහා HTTPS, restrictive `CORS_ORIGINS`, rate limiting, request size limits, abuse protection සහ log/privacy policy එකක් එක් කරන්න. Android manifest-හි cleartext traffic allow කරන්නේ development LAN testing සඳහා පමණක් නම් release එකට පෙර ඉවත් කරන්න/HTTPS පමණක් භාවිතා කරන්න.

## 6. Included screens/features

- Animated splash + Sinhala/English sign-in/signup + local demo entry
- Signup අතර Grade 1–13 සහ A/L stream තේරීම
- Home dashboard, streak, quick links, subject grid, bottom navigation
- Grade group → stream → subject → chapter flow
- Chapter tabs: Notes, Video, Quiz, Past papers, Context-aware Chat
- FastAPI AI chat client, typing state, sources, voice input/output, homework image OCR
- Timed MCQ quiz, instant explanation, result celebration, PDF result export
- Past-paper/year/marking-scheme filters + PDF download/view hooks
- Fl Chart progress dashboard
- Hive local profile/chat/quiz/cache + downloaded PDFs
- Firebase Auth/Firestore/Storage hooks, dark/light mode, language/settings UI

## 7. Implementation map

```text
edumate_flutter/
├── pubspec.yaml
├── analysis_options.yaml
├── assets/lottie/study_buddy.json
└── lib/
    ├── main.dart
    ├── data/                 # Sinhala/English labels + demo curriculum
    ├── models/               # profile, subject, chapter, chat, quiz
    ├── providers/            # Hive-backed app state
    ├── screens/              # auth, shell, home, curriculum, chat, quiz, library, profile
    ├── services/             # Firebase, AI API, papers, PDFs, offline cache
    ├── theme/                # Material 3 light/dark themes
    └── widgets/              # shared cards, banners and progress UI

edumate_backend/
├── main.py                   # FastAPI: /api/chat, /api/health, PDF exports
├── requirements.txt
├── .env.example
├── firestore.rules.example
└── tests/test_main.py
```

## 8. Tests / troubleshooting

```bash
cd edumate_backend
python -m unittest discover -s tests -v
```

- Firebase not configured? `Explore demo mode` still works.
- Chat says Offline preview? Check `/api/health`, backend URL, emulator `10.0.2.2`, CORS, and `LLM_ENDPOINT` on the server.
- Papers show “PDF link not configured”? Upload a PDF and seed its Firestore metadata; demo does not ship copyrighted exam documents.
- Sinhala OCR accuracy varies: ML Kit Latin recognizer is used by default; photo questions with Sinhala-only print may need manual correction or a Sinhala-capable OCR service/model.
- Sinhala PDF glyphs need a Sinhala-capable TTF path in `EDUMATE_PDF_FONT_PATH` on the backend.
- Notifications are a preference UI only in this MVP; push/local notification scheduling needs FCM or a local-notification plugin plus user consent.
