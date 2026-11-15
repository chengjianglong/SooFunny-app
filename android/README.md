# SooFunny for Android

The Android version of SooFunny, in Kotlin and Jetpack Compose. It shares its content with the
iOS app in `../SooFunny/` (the word list, word photos, gallery photos, sports and books), so
there is one copy of everything a child sees. Like the iOS app it works fully offline: the app
has no `INTERNET` permission, no accounts and no ads, and nothing leaves the device.

## What's in this version (0.3)

The five tabs, in the iOS order, with the **English / 中文 / Bilingual 双语** switch (🌐 in the
top bar of every tab and in Settings → Language 语言). The choice is saved and applies to every tab.

| Tab | In 0.1 |
|---|---|
| 🎨 **Color** | The gallery (21 photos and 4 drawings in five groups, Surprise me!), your own picture from **Photos** or the **Camera**, and coloring pages made on the device: Big / Medium / Small blocks, tap or drag to fill, Undo, Magic, Real, Peek, Clear, Eraser, 18 crayons plus **More colors**; **Share** or **Save** (to Pictures › SooFunny) the finished picture |
| 🔤 **Words** | 32 groups, 754 words with their Chinese, emoji and the 516 real photos; a word page that reads the word, lets kids tap each letter or character, and Previous / Next |
| 🏃 **Sports** | 51 summer and winter sports with photos, names and introductions in both languages, read aloud on opening with the words lighting up, and a looping **Watch it! 看一看！** animation for each (paused when animations are turned off) |
| 📚 **Books** | The 10 built-in story books, page by page in English, Chinese or both, with **Read to me** turning pages by itself and highlighting each word. **My books**: **Scan a book** with the camera or add pages **From Photos**; the words are read on the device (English, Chinese or both), and grown-ups can name the book, fix the words, remove pages and change their order before saving. Then **Read along** with each page's photo, the English in the English voice and the Chinese in the Chinese voice; pinyin is skipped. Books are kept in the app's own storage |
| ➕ **Math** | Flashcard Game, Quiz, results with stars, Progress Reports and math settings, following the same rules as iOS |
| ⚙️ **Settings** | Language, reading speed, try the English and Chinese voices, photo credits, reset, About |

Reading aloud uses the device's own text-to-speech voices (Google's on most phones), English
and Chinese each in its own voice. Settings warns when no Chinese voice is installed.

## Plan for later versions

| Phase | What | Notes |
|---|---|---|
| 2 ✅ | Sports animations (**Watch it!**), Camera on Color, Share/save the colored picture, More colors | Done in 0.2, with no new dependencies |
| 2 ✅ | **My books**: scan or pick pages and read them aloud | Done in 0.3 with ML Kit (below). Still to do: **Make audiobook** (an `.m4a` of the whole book) |
| 3 | **Natural voices**: Kokoro-82M English and Chinese through ONNX Runtime for Android, with a Kotlin port of the English phonemizer and `ChineseG2P` | Adds ~250 MB of models, so it needs a download-on-first-use or Play Asset Delivery decision |
| 3 | **Talking buddy**: Qwen 2.5 1.5B with llama.cpp (NDK), on-device speech recognition | About 1 GB model; needs the same delivery decision and testing on low-memory phones |
| 3 | Subject detection for coloring pages (Apple Vision on iOS) | ML Kit subject segmentation needs Google Play services; to decide |
| 4 | Google Play: signing, store listing, Data safety form, tips with Play Billing | Ask before publishing |

## ML Kit and privacy

My books uses two Google ML Kit libraries, added in 0.3:

- **Text recognition** (`com.google.mlkit:text-recognition-chinese`, bundled model): reads
  Chinese and English on the device. The model is inside the APK, so it works offline. It
  makes the debug APK about 100 MB instead of about 57 MB; a Play App Bundle splits it per
  device, so phones download less.
- **Document scanner** (`play-services-mlkit-document-scanner`): Google Play services' own
  scanning screen, which finds and flattens the page. Play services downloads it the first
  time it's used, so it needs a phone with the Play Store. The emulator images without the
  Play Store can't install it and show "Something went wrong"; use **From Photos** there.

ML Kit's libraries ask for network access to log usage. The manifest removes `INTERNET` and
`ACCESS_NETWORK_STATE` (`tools:node="remove"`), so the app still can't send anything; check
with `app/build/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml`.

## Building and running

Requirements: JDK 17 or later (21 tested), the Android SDK with platform 37 and build tools,
and an emulator or phone on Android 8.0 (API 26) or later. Android Studio works too: open the
`android/` folder.

```bash
cd android
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties   # once, if Android Studio hasn't made it
./gradlew :app:assembleDebug                                   # builds app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:installDebug                                    # installs on the running emulator or phone
./gradlew :app:testDebugUnitTest                               # JVM tests (word list, coloring engine, math rules)
```

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
