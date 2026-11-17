# SooFunny for Android

The Android version of SooFunny, in Kotlin and Jetpack Compose. It shares its content with the
iOS app in `../SooFunny/` (the word list, word photos, gallery photos, sports and books), so
there is one copy of everything a child sees. Like the iOS app it has no accounts and no ads,
and nothing a child says, draws, scans or photographs leaves the device. The internet is used for
one thing only: downloading the talking buddy's model the first time it's needed (plus
optional tips and asking Google Play whether there's a newer version; see
[Privacy](#privacy-and-the-internet)).

## What's in this version (0.4)

The five tabs, in the iOS order, with the **English / 中文 / Bilingual 双语** switch (🌐 in the
top bar of every tab and in Settings → Language 语言). The choice is saved and applies to every tab.

| Tab | What's there |
|---|---|
| 🎨 **Color** | The gallery (21 photos and 4 drawings in five groups, Surprise me!), your own picture from **Photos** or the **Camera**, and coloring pages made on the device: Big / Medium / Small blocks, tap or drag to fill, Undo, Magic, Real, Peek, Clear, Eraser, 18 crayons plus **More colors**; **Share** or **Save** (to Pictures › SooFunny) the finished picture |
| 🔤 **Words** | 32 groups, 754 words with their Chinese, emoji and the 516 real photos; a word page that reads the word, lets kids tap each letter or character, and Previous / Next; ✨ **Talk about …** opens the talking buddy |
| 🏃 **Sports** | 51 summer and winter sports with photos, names and introductions in both languages, read aloud on opening with the words lighting up, a looping **Watch it! 看一看！** animation for each (paused when animations are turned off), and **Talk about …** with the buddy, who knows the sport's introduction |
| 📚 **Books** | The 10 built-in story books, page by page in English, Chinese or both, with **Read to me** turning pages by itself and highlighting each word. **My books**: **Scan a book** with the camera or add pages **From Photos**; the words are read on the device (English, Chinese or both), and grown-ups can name the book, fix the words, remove pages and change their order before saving. Then **Read along** with each page's photo, the English in the English voice and the Chinese in the Chinese voice; pinyin is skipped. **Make audiobook** records the whole book to an `.m4a` to listen to anytime; sharing it needs the "Ask a grown-up" check. Books are kept in the app's own storage |
| ➕ **Math** | Flashcard Game, Quiz, results with stars, Progress Reports and math settings, following the same rules as iOS |
| ⚙️ **Settings** | Language, English voice (Natural · Heart or the device voice), Chinese voice (five natural voices), reading speed, Try the voice, photo credits, reset, About |
| ✨ **Talking buddy** | Qwen 2.5 1.5B running on the device with llama.cpp: explains the word or sport, asks "What would you like to know about …?", listens (on-device speech recognition only) or takes a typed question, and answers in a few short sentences, read aloud as they're written with each word lit up. English, Chinese or Bilingual, with **I speak English / 我说中文**. Needs a one-time 1.1 GB download, started by a grown-up on the buddy screen |

Reading aloud uses the natural **Kokoro-82M** voices, run on the device with ONNX Runtime: English
("Heart", 8-bit) and Chinese (v1.1-zh, 16-bit, five voices), with Kotlin ports of the iOS app's
English phonemizer and `ChineseG2P` (it matches misaki on all 1,133 Chinese strings in the app).
Without the voice models (a plain `installDebug`), the device's text-to-speech voices are used.

**Slow phones.** Kokoro needs a fast CPU: on a Unisoc T606 (BLU G45) it takes about 3.5 s to make
one second of speech. The app times its first phrases, and where making speech is slower than
0.8× real time it stops making speech on the phone and remembers that (Settings explains it and
offers "Use the natural voices anyway"). Everything that's always read the same way (words and
groups, letters, sports, the story books, math questions and cheers, the buddy's opening
question) still plays at once in the natural voice, from **pre-made clips** made on a computer with
the same model and the same phrase splitting, at normal speed in the default voices, in the
`voices` pack. Anything else (the buddy's answers, scanned books, other speeds or Chinese voices)
uses the device's voice there.

The talking buddy on the same phone: the model is loaded and its shared instructions are read in
the background as soon as a word list or a sport opens, prompts reuse what the model has already
read, and it uses up to six threads (2.5× faster prompt reading than four on that chip). The first
answer starts about 4 s after ✨ instead of about 40 s.
Coloring pages use ML Kit subject segmentation, when Google Play services has its model, so the
subject of a photo gets more detail than the background (as Apple Vision does on iOS).

## Plan for later versions

| Phase | What | Notes |
|---|---|---|
| 2 ✅ | Sports animations (**Watch it!**), Camera on Color, Share/save the colored picture, More colors | Done in 0.2, with no new dependencies |
| 2 ✅ | **My books**: scan or pick pages and read them aloud | Done in 0.3 with ML Kit (below). Still to do: **Make audiobook** (an `.m4a` of the whole book) |
| 3 ✅ | **Natural voices**: Kokoro-82M English and Chinese through ONNX Runtime | Done in 0.4; the models ship in the `voices` Play Asset Delivery pack (install-time) |
| 3 ✅ | **Talking buddy**: Qwen 2.5 1.5B with llama.cpp (NDK), on-device speech recognition | Done in 0.4; the model is downloaded on first use. Still to test on low-memory phones |
| 3 ✅ | **Make audiobook**, subject detection for coloring pages | Done in 0.4 |
| 4 | Google Play: signing, store listing, Data safety form | In progress: see [PLAY_LISTING.md](PLAY_LISTING.md). Release signing is set up, the release bundle builds, a grown-up check guards the model download and each buddy answer has a Report button |
| 5 ✅ | Tips with Play Billing | The same three one-time tips as iOS (Settings → Support SooFunny → Leave a tip), `core/TipJar.kt`; the products are set up in Play Console (see PLAY_LISTING.md) |
| 5 ✅ | Update reminder | "A new SooFunny is ready!" when Play has a newer version (checked at most every 6 hours; Not now hides it for 3 days), then Play's in-app update after the grown-up check, as on iOS (`core/AppUpdate.kt`, `core/UpdatePolicy.kt`) |

## ML Kit

My books uses two Google ML Kit libraries, added in 0.3:

- **Text recognition** (`com.google.mlkit:text-recognition-chinese`, bundled model): reads
  Chinese and English on the device. The model is inside the APK, so it works offline. It
  makes the debug APK about 100 MB instead of about 57 MB; a Play App Bundle splits it per
  device, so phones download less.
- **Document scanner** (`play-services-mlkit-document-scanner`): Google Play services' own
  scanning screen, which finds and flattens the page. Play services downloads it the first
  time it's used, so it needs a phone with the Play Store. The emulator images without the
  Play Store can't install it and show "Something went wrong"; use **From Photos** there.

- **Subject segmentation** (`play-services-mlkit-subject-segmentation`, beta), added in 0.4:
  finds the subject of a photo for coloring pages. Play services installs its model once; until
  then (or without Play services) photos are segmented as one picture, as before.

## Privacy and the internet

- The app has the `INTERNET` permission for **one download**: the buddy's model (Qwen 2.5 1.5B
  Instruct, 1.1 GB, from Hugging Face, checked against its SHA-256 and resumable;
  `core/ModelFiles.kt`). A grown-up starts it on the buddy screen. Nothing about the child is sent.
- Libraries that would otherwise send usage data are switched off in the manifest
  (`tools:node="remove"`): ML Kit's data-transport upload service, scheduler and backend, ONNX
  Runtime's `TelemetryInitializer` (telemetry is also turned off in code), and the
  `ACCESS_NETWORK_STATE` permission they ask for. Check the result in
  `app/build/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml`.
- The buddy listens **only with the on-device speech recognizer** (Android 12 and later). If the
  phone has none for the chosen language, the buddy asks the system to add it and the child types
  instead; the server recognizer is never used, so what a child says stays on the device.
- Play services' own document scanner and the ML Kit model installs are done by Google Play
  services, not by the app.

## Building and running

Requirements: JDK 17 or later (21 tested), the Android SDK with platform 37 and build tools,
and an emulator or phone on Android 8.0 (API 26) or later. Android Studio works too: open the
`android/` folder.

Get the voice models first (they aren't in git), from the repository root: `scripts/fetch_model.sh`
puts them in `Models/`, and the build copies them into the `voices` asset pack. Then make the
pre-made clips (macOS, about 8,000 phrases and 100 MB, also not in git; run it again after changing words, sports,
books or math, and it only makes what's new):
`./gradlew :app:testDebugUnitTest --tests '*PremadeVoiceRenderer*' -PpremadeOut=voices/src/main/assets/premade`. The NDK
(28.2.13676358) and CMake (3.22.1) build llama.cpp for the buddy; the build uses
`Vendor/llama.cpp-src` if it's there, else fetches tag b11577 from GitHub.

```bash
cd android
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties   # once, if Android Studio hasn't made it
./gradlew :app:installDebug                                    # quick install, without the voice models (device voices)
./gradlew :app:installDebug -PwithModels=true                  # debug APK with the voice models inside (about 250 MB more)
./tools/install_bundle.sh                                      # the App Bundle with its asset pack, installed the way Google Play would (bundletool)
./gradlew :app:testDebugUnitTest                               # JVM tests (word list, coloring engine, math, voices, buddy, books)
```

The buddy's model is downloaded by the app itself on first use (1.1 GB). On an emulator the
buddy runs on the x86_64 or arm64 CPU build; expect it to be slow there.

### Release bundle for Google Play

```bash
./tools/make_upload_key.sh       # once: makes upload-key.jks and keystore.properties (never committed; back them up)
./gradlew :app:bundleRelease     # app/build/outputs/bundle/release/app-release.aab, signed with the upload key
```

The release build is minified with R8 (keep rules in `app/proguard-rules.pro`) and ships only
64-bit code (arm64-v8a, x86_64). Without `keystore.properties` the bundle is built unsigned.
The store listing, Data safety answers and submission steps are in [PLAY_LISTING.md](PLAY_LISTING.md).

If `java` isn't on the PATH, point `JAVA_HOME` at a JDK, for example
`export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`.

To start an emulator from the command line: `~/Library/Android/sdk/emulator/emulator -list-avds`,
then `~/Library/Android/sdk/emulator/emulator -avd <name>`. For Chinese to be read aloud, the
emulator or phone needs a Chinese text-to-speech voice (Android Settings → System → Languages →
Text-to-speech output → Speech Services by Google → Install voice data → Chinese).

## How the content is shared with iOS

- **Read straight from `../SooFunny/` at build time** by the `copyIosAssets` Gradle task, into
  the APK's assets: `Words/kids_words.txt`, `Words/Photos/*.jpg` and their credits, and
  `Showcase/*.jpg` with `credits.json`. Edit them once and both apps get the change.
- **Exported from Swift to JSON**: the sports (`Sports/OlympicSports.swift`) and the books
  (`Books/StoryBooks.swift` with `StoryTranslations.swift`) live in Swift code, so
  `tools/export_ios_data.py` turns them into `app/src/main/assets/data/sports.json` and
  `books.json`. Run it after changing those files:

  ```bash
  python3 android/tools/export_ios_data.py
  ```

## Project layout

```
android/
  app/src/main/java/com/chengjianglong/soofunny/
    MainActivity.kt        the five tabs, Settings and the coloring screen
    core/                  language setting, speech, shared content (words, sports, books), asset photos
    engine/                coloring-page engine (a port of SooFunny/Engine)
    ui/                    common pieces (top bar, 🌐 switch, bouncing title) and one folder per tab;
                           ui/sports/ has the animation engine (a port of SportDemo/SportDemos/DemoScenes)
  app/src/main/assets/data/ sports.json and books.json, exported from the iOS sources
  app/src/test/            JVM unit tests
  tools/export_ios_data.py
```
