# SooFunny 🖍️

**Color, words, books, sports and math for kids, on iPhone and iPad, completely offline.**

SooFunny turns any picture into a coloring page, lets kids explore 754 English words with a
talking buddy that answers their questions out loud, reads picture books aloud (including the
family's own books, scanned in English, Chinese or both), makes math practice feel like a game,
and introduces 51 summer and winter sports in English and Chinese.
Everything runs on the device: no Wi‑Fi, no accounts, no ads, and nothing a child says, draws or
photographs ever leaves the device.

<p align="center"><img src="SooFunny/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="140" alt="SooFunny app icon"></p>

<p align="center">
  <a href="marketing/SooFunny-presentation.mp4"><img src="docs/images/presentation-poster.jpg" width="640" alt="Play the 2-minute SooFunny presentation video"></a><br>
  <b>▶️ <a href="marketing/SooFunny-presentation.mp4">Watch the 2-minute presentation</a></b>: every feature, narrated in the app's own voice
</p>

<p align="center">
  <a href="marketing/SooFunny-demo-iPhone16.mp4"><img src="docs/images/demo-iphone16.jpg" width="250" alt="Play the SooFunny demo video for iPhone 16"></a>
  &nbsp;
  <a href="marketing/SooFunny-demo-iPad.mp4"><img src="docs/images/demo-ipad.jpg" width="250" alt="Play the SooFunny demo video for iPad"></a><br>
  <b>▶️ Watch the demo: <a href="marketing/SooFunny-demo-iPhone16.mp4">iPhone 16</a> (104 s) · <a href="marketing/SooFunny-demo-iPad.mp4">iPad</a> (104 s)</b><br>
  Coloring, words with real photos, the talking buddy, books read aloud, and math<br>
  🏅 <a href="marketing/SooFunny-sports.mp4">Sports animations</a> (36 s, 12 sports, new in 0.3)<br>
  📑 <a href="marketing/SooFunny-slides.pdf">Introduction slides</a> (PDF, 12 slides)
</p>

<p align="center">
  <img src="docs/images/iphone-color.jpg" width="190" alt="Color tab on iPhone: picture gallery with a Surprise me! button">
  &nbsp;
  <img src="docs/images/ipad-words.jpg" width="250" alt="Words tab on iPad: 32 word groups">
  &nbsp;
  <img src="docs/images/iphone-books.jpg" width="190" alt="Books on iPhone: The Three Little Pigs read aloud, one word highlighted">
  &nbsp;
  <img src="docs/images/iphone-sports.jpg" width="190" alt="Sports on iPhone: Swimming in English and Chinese, with swimmers racing down their lanes">
  &nbsp;
  <img src="docs/images/iphone-math.jpg" width="190" alt="Math tab on iPhone: flashcards, quiz and progress reports">
</p>

<p align="center"><img src="docs/images/photo-to-page.jpg" width="900" alt="Photos of a goldfish, a parrot and a lighthouse next to the coloring pages SooFunny makes from them"></p>

| | |
|---|---|
| **Version** | 0.3 (build 5) in App Review; 0.2 (build 3) is [on the App Store](https://apps.apple.com/us/app/soofunny/id6827777441) |
| **Platforms** | iPhone and iPad, iOS 17 or later, all orientations |
| **Developer** | [Chengjiang Long](https://www.chengjianglong.com/) |
| **Copyright** | © 2026 Soo X Intelligence LLC. All rights reserved. |

---

## Contents

- [Features](#features)
- [How it works](#how-it-works)
- [Free, with optional tips](#free-with-optional-tips)
- [Privacy and child safety](#privacy-and-child-safety)
- [Building and running](#building-and-running)
- [Tests](#tests)
- [Project layout](#project-layout)
- [Changing content](#changing-content)
- [Releasing on the App Store](#releasing-on-the-app-store)
- [Performance](#performance)
- [Known limitations](#known-limitations)
- [Credits and licenses](#credits-and-licenses)

---

## Features

### 🎨 Color

- **A playful gallery**: a bouncing rainbow title, a **Surprise me!** button that opens a random
  picture, and sticker-style cards in five groups: **Animals**, **Faces**, **People**,
  **Outdoors** and **Drawings**. That's 21 free (CC0) photos plus 4 drawings made in code
  (House, Fish, Flower, Rocket).
- **Your own pictures**: **Photos** and **Camera** buttons at the bottom of the page.
- **Automatic coloring pages**: any picture becomes clean black outlines around kid-sized blocks.
  Choose **Big**, **Medium** or **Small** blocks.
- **Easy coloring**: tap a block, or drag a finger across several. Taps on a line snap to the
  nearest block.
- **Tools**: Undo, **Magic** (random colors everywhere), **Real** (each block in its photo
  color), **Peek** (see the original underneath), Clear, Eraser and a custom color picker. 18
  crayon colors.
- **Share or save** the finished picture with the system Share button.

### 📚 Words

- **32 word groups, 754 words**, written for SooFunny: Animals, Farm, Sea Creatures, Bugs,
  Birds, Fruit, Vegetables, Food, Sweets, Drinks, Colors, Shapes, Numbers, My Body, Clothes,
  At Home, Kitchen, School, Toys and Games, Sports, Music, Going Places, Weather, Seasons and
  Time, Nature, Space, Jobs, People, Feelings, Action Words, Opposites and Around Town.
- Every word has an emoji picture (or a colorful letter tile) and a **speaker** button.
  516 of the 754 words also show a **real photo**, with the emoji stuck on its corner like a
  sticker. On the talking buddy screen, most of them show one or two more photos beside it. Words that can't be photographed well (numbers, feelings, time words) keep just the
  emoji.
- A word page shows the word big, reads it aloud, lets kids tap each **letter** to hear it, and
  has Previous / Next.
- Tap a group to see its words; **Back** returns to the groups.

### ✨ Talking buddy

Every word has a sparkle **Talk about it** button that opens a spoken conversation, inspired by
the [Wonder Words Agent demo](https://www.youtube.com/shorts/ZAaAPILTohk):

1. The buddy explains the word in a sentence or two, then asks
   *"What would you like to know about lion?"*
2. It listens. The child asks out loud ("What does a lion eat?") or types a question.
3. It answers in a few short, kind sentences, read aloud with each word highlighted, then
   listens again.

The big button follows the turn: **Talk**, **Done** (while listening), **Cancel** (while
thinking) and **Stop speaking**. The answers come from Google's **Gemma 3 1B**, running on the
device.

### 📖 Books

- **Story books**: 10 books, SooFunny's own short retellings of public-domain tales and rhymes, including The Three Little Pigs,
  Goldilocks, The Gingerbread Man, nursery rhymes, and two in Chinese (唐诗五首 Tang Poems and
  龟兔赛跑 The Tortoise and the Hare).
- **Read aloud**: tap **Read to me** (读给我听 in Chinese books) and each page is read with the
  current word lit up, turning pages by itself. Swipe or tap the arrows to turn pages by hand.
- **My books**: **Scan a book** with the camera (one or many pages) or pick pages **From
  Photos**. The text is read from each page on the device, in English, Chinese or a mix of both.
  Before saving, grown-ups can fix the words, remove pages and **Change page order** by dragging.
- **Mixed languages**: English parts are read in the natural voice and Chinese parts in Apple's
  Chinese voice, one after another. Pinyin printed above the characters is skipped.
- **Audiobooks**: **Make audiobook** records the whole book into an `.m4a` file to listen to
  anytime or share.

### 🏅 Sports

<p align="center">
  <img src="docs/images/sports-animations.gif" width="400" alt="Animations from the Sports tab: swimming, archery, gymnastics, figure skating, bobsleigh and ski jumping">
  &nbsp;
  <img src="docs/images/ipad-sports.jpg" width="276" alt="Sports tab on iPad: Summer and Winter buttons above a grid of sports with English and Chinese names">
</p>

- **51 sports**: the 35 summer and 16 winter sports on the 2024 and 2026 Games programmes,
  switched with the **Summer 夏季** and **Winter 冬季** buttons. On-screen text and the store
  listing don't name the Games, since App Review rejects unlicensed use of those trademarks;
  `SportsTests` checks for them.
- Each sport has an emoji (and a real photo for 12 of them, shared with the Words tab), its
  English and Chinese names, and a short introduction written for children in **both languages**.
- **Watch it! 看一看！** plays a looping animation of each sport: swimmers racing down their
  lanes, a diver flipping into the pool, an arrow flying into the target, a bobsled racing down the
  ice chute, and so on. Tap pause to stop it; it starts paused when Reduce Motion is on.
- Under **What is it?**, **Read to me** reads the English in the natural voice, and under
  **这是什么运动？**, **读给我听** reads the Chinese in Apple's Chinese voice, each word lighting up
  as it's read. Tap a name to hear it, and Previous / Next move through the sports.
- The sports are in `SooFunny/Sports/OlympicSports.swift` and their animations in `SportDemos.swift`
  (a scene from `DemoScenes.swift` plus emoji and balls moving along keyframed paths, drawn by
  `SportDemo.swift`). The whole tab is free.

### ➕ Math

Inspired by [Best Math App for Kids](https://www.youtube.com/watch?v=hVBYZOaC5iw):

- **Flashcard Game**: choose operations (+ − × ÷), the numbers 0–12 to focus on, 10/20/30
  questions, and whether to mark answers. Problems are stacked the school way; tap to reveal,
  then **Got it!** or **Not yet**.
- **Quiz**: "5 − 1 = ?" with a big number pad, a ✓ or ✗ (with the right answer), a timer and
  read-aloud questions.
- **Results**: stars, confetti for a perfect round, and **Practice missed ones**.
- **Progress Reports**: rounds, questions, a day streak, accuracy for each operation, and the
  trickiest facts to practice again.
- **Rules**: every question includes a chosen focus number, subtraction never goes below zero,
  and division always comes out even (never ÷ 0).

### 🗣️ Natural voice

Words, letters, books, math, sports and the talking buddy are read by **Kokoro-82M**, a neural voice
("Heart", a warm American female voice) that runs on the device. Chinese text is read by
Apple's built-in Chinese voice. Apple's built-in voices are
still available in Settings, minus novelty voices like "Boing". If the natural voice can't load,
the app uses an Apple voice automatically.

### ⚙️ Settings

- **Support SooFunny**: **Leave a tip**, behind the grown-up check.
- **Reading voice**: the voice, its speed (default about 1.05×) and a **Try the voice** button.
- **Research Lab** (for grown-ups): device info and on-device benchmarks of the coloring
  pipeline, Apple's Vision subject model and Apple's on-device language model (Apple
  Intelligence, iOS 26+), plus a prompt playground. Results stay on the device and export as
  JSON/CSV.
- **Photo credits**, **Reset defaults**, and **About** (version, developer, copyright).

### 📱 iPhone and iPad

On iPhone, the tabs sit at the bottom and the crayons scroll in one row. On iPad, the tabs sit at
the top, the crayons wrap into a grid, and in landscape the coloring tools move to a sidebar so
the picture stays big.

---

## How it works

### Coloring pages (`SooFunny/Engine/`)

**Drawings** (mostly black lines on white) keep their own lines: each enclosed area becomes a
block.

**Photos** go through a sketch pipeline:

1. **Flatten.** Repeated Kuwahara filtering in CIE Lab color removes texture and shading but
   keeps real edges sharp (`LabImage.swift`).
2. **Find the subject.** Apple's on-device Vision model separates people, pets and objects from
   the background (`SubjectMask.swift`). The subject gets more detail and the background stays
   simple, and no block mixes the two. Photos without a clear subject skip this step.
3. **Group colors.** k-means in Lab color (seeded, so results repeat), separately for subject and
   background, then a majority filter.
4. **Merge.** Neighboring blocks that look alike (small ΔE) join, so a sky stays one block. Tiny
   pieces and slivers merge into the neighbor they share the longest border with, until the
   count fits the chosen block size.
5. **Smooth.** Borders are rounded off, then redrawn at 1024 px with Gaussian-weighted contour
   smoothing, so lines look drawn rather than pixelated.
6. **Outline.** A distance transform draws an even, anti-aliased line about 3 px wide along every
   border.

### Talking buddy (`SooFunny/Assistant/`)

- **Thinking:** Gemma 3 1B (4-bit, Q4_K_M) is bundled with the app and runs with
  [llama.cpp](https://github.com/ggml-org/llama.cpp), built from source as an XCFramework.
- **Prompting:** answers are kept short and child-safe, with the last eight turns of the
  conversation as context. The app adds the "What would you like to know about …?" question
  itself, because a small model doesn't ask it reliably, and trims replies to a few sentences.
- **Listening:** Apple's speech recognition, required to run on the device. A turn ends after a
  1.4 s pause, after 8 s of silence, or after 20 s.
- **Speaking:** answers stream sentence by sentence into the voice, so speech starts before the
  whole answer is written.

### Books (`SooFunny/Books/`)

- **Scanning:** VisionKit's document camera finds and flattens each page; Vision's text
  recognizer reads it on the device (English, Simplified and Traditional Chinese). Lines are
  joined back into sentences, hyphens are rejoined, and page numbers are dropped.
- **Languages:** text is split into runs by script: Han characters are Chinese, other letters
  English. Pinyin (words with tone marks such as ā or ǎ) is removed before reading.
- **Reading:** each run goes to the voice for its language, and runs play one after another.
- **Audiobooks:** `AudiobookMaker` renders every page to audio, with short pauses between
  phrases and longer ones between sentences, and writes an AAC `.m4a`. Phrases that can't be
  spoken are skipped instead of failing the whole book.
- **Storage:** scanned books (page images, text and audiobook) are kept in the app's own
  Application Support folder.

### Natural voice (`SooFunny/Voice/`)

- **The voice:** [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) (8-bit, 92 MB) with the
  "Heart" voice, run with [ONNX Runtime](https://github.com/microsoft/onnxruntime-swift-package-manager)
  on the CPU.
- **Pronunciation:** text becomes phonemes with a Swift port of the dictionary rules of
  [misaki](https://github.com/hexgrad/misaki), Kokoro's own phonemizer. It uses a
  183,561-word US dictionary, rules for small words ("a", "the", "to"…) and for -s, -ed and -ing
  endings, and spells out numbers. Unknown words are spelled letter by letter. The GPL
  espeak-ng phonemizer is deliberately not used.
- **No dead air:** the silence Kokoro adds around each clip is trimmed, and short natural pauses
  are added instead (0.22 s after a sentence, 0.12 s after a phrase). Long sentences are split
  at commas so speech starts after the first phrase.
- **Instant taps:** recent clips are remembered (up to 400), and likely-next speech is prepared
  in the background: group names, the words in an open group, the next and previous word, its
  letters, every question in a math round, and common cheers. Anything a child taps goes first.
- **Highlighting:** Kokoro doesn't report word timings, so the buddy's word highlighting is
  estimated from each word's length.

---

## Free, with optional tips

**Every feature is free for everyone**, with no locks, limits, ads or accounts, from version 0.3.
Grown-ups who'd like to help keep SooFunny maintained and updated can leave a tip in
**Settings → Support SooFunny**, behind the grown-up check.

| Tip | Price (US) | Product ID |
|---|---|---|
| ☕️ Small | $1.99 | `com.chengjianglong.soofunny.tip.small` |
| 🍰 Medium | $4.99 | `com.chengjianglong.soofunny.tip.medium` |
| 🎁 Large | $9.99 | `com.chengjianglong.soofunny.tip.large` |

- **How:** tips are consumable In-App Purchases (StoreKit 2, `SooFunny/Store/TipJar.swift`) that
  unlock nothing. Apple requires In-App Purchase for tips to a developer that isn't a registered
  nonprofit, so there's no outside donation link in the app.
- **Offline:** the tip screen needs the App Store; offline it says so. Everything else works
  offline as before.
- **Former subscribers:** versions 0.1 and 0.2 sold a yearly subscription
  (`com.chengjianglong.soofunny.premium.yearly`). Anyone whose subscription is still set to renew
  sees a note in Settings with a **Manage subscription** button to cancel it.
- **Testing purchases:** `SooFunny/Store/SooFunny.storekit` holds the three tips and the old
  subscription, so both can be tried in Xcode; the scheme uses it when you press **Run**.

---

## Privacy and child safety

- **No data collected.** No analytics, ads, tracking, accounts or servers. The privacy manifest
  (`SooFunny/PrivacyInfo.xcprivacy`) declares no tracking and no collected data.
- **Photos** are turned into coloring pages on the device and are never uploaded.
- **Scanned books** are read and stored on the device only; their pages and audiobooks leave it
  only if a grown-up shares them.
- **Voice** is recognized on the device only and never recorded or saved. If a device can't
  recognize speech on the device, the buddy doesn't listen; children can type instead.
- **The buddy and the voice** run entirely on the device. Conversations are forgotten when you
  leave the screen.
- **Progress and settings** are stored only on the device.
- **Grown-up check:** purchases, the developer's website and the Research Lab sit behind a
  grown-up check. The photo credits are shown as text, not links.
- **Permissions:** the camera, microphone, speech recognition and saving to Photos are each
  requested only when first used.

Full policy: [PRIVACY.md](PRIVACY.md).

---

## Building and running

### Requirements

- A Mac with **Xcode 26 or later** (developed with Xcode 27.1), which includes the iOS SDK.
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** and **CMake**:

```bash
brew install xcodegen cmake
```

- **Python 3**. `scripts/make_icon.py` also needs Pillow (`pip install pillow`).
- About **2 GB** of free disk space for the models and builds.

### 1. Get the large pieces (not stored in git)

```bash
./scripts/build_llama.sh
```

This builds llama.cpp (tag `b11577`) as an XCFramework for iOS devices and the Simulator, into
`Vendor/`. It takes a few minutes.

```bash
./scripts/fetch_model.sh
```

This downloads into `Models/`, checking each file's SHA-256:

- Gemma 3 1B `gemma-3-1b-it-Q4_K_M.gguf` (806 MB)
- Kokoro-82M `kokoro-82m-q8.onnx` (92 MB)

Both models are bundled into the app (about 918 MB in total), so it works offline from the
first launch.

### 2. Generate the Xcode project and open it

```bash
xcodegen generate
```

```bash
open SooFunny.xcodeproj
```

The project is generated from `project.yml`; run `xcodegen generate` again after adding or
removing files. Swift packages (ONNX Runtime 1.24.2) resolve automatically. If command-line
builds fail to resolve them, add `-scmProvider system` to `xcodebuild`.

### 3. Run

- **Simulator:** pick an iPhone or iPad simulator and press **Run**.
- **Your iPhone or iPad:**
  1. Connect it, turn on Developer Mode, and set your Team under *Signing & Capabilities*.
  2. Press **Run**.
  3. The first time, iOS needs **internet once** to verify the developer. If the app won't open,
     go to Settings → General → VPN & Device Management → your developer → **Verify App**.

  With a free Apple ID, device installs expire after 7 days; with the paid Developer Program they
  last a year.

  If a build fails with **"No Accounts"** or **"No profiles for 'com.chengjianglong.soofunny'"**,
  Xcode has lost its sign-in or the development profile has expired: sign in again under
  *Xcode → Settings → Accounts* and build again; Xcode makes a new profile automatically.

From the command line:

```bash
xcodebuild build -project SooFunny.xcodeproj -scheme SooFunny -configuration Debug -destination 'id=<device UDID>' -derivedDataPath build-device -scmProvider system DEVELOPMENT_TEAM=<Team ID> -allowProvisioningUpdates
```

```bash
xcrun devicectl device install app --device <device UDID> build-device/Build/Products/Debug-iphoneos/SooFunny.app
```

---

## Tests

```bash
xcodebuild test -project SooFunny.xcodeproj -scheme SooFunny -destination 'platform=iOS Simulator,name=<simulator>' -scmProvider system
```

81 unit tests in `SooFunnyTests/`:

| File | What it checks |
|---|---|
| `ImageSegmenterTests` | Blocks and outlines for photos and drawings, gradients, subjects, block limits, rendering |
| `WordDictionaryTests` | Word list format and contents, Research Lab statistics and export, bundled gallery and word photos and their credits |
| `WordAssistantTests` | Prompts, sentence streaming and the buddy's turn flow (with fakes), plus real Gemma runs |
| `NaturalVoiceTests` | Pronunciations, Swift audio vs. the reference pipeline, speed, phrases, silence trimming, voice choices |
| `BooksTests` | Story library, text recognition in English and Chinese, line joining, mixed-language splitting and pinyin, saving, reordering, and audiobooks |
| `MathTests` | Question rules, flashcard and quiz sessions, scoring, progress and streaks |
| `SportsTests` | Every sport has unique English and Chinese names, introductions in each language, a bundled photo where it reuses one, a working animation, and no trademarked Games names. With `TEST_RUNNER_SPORT_DEMO_SHEETS=<folder>`, it also draws frames of every animation into that folder for checking by eye |
| `TipJarTests` | The three tips and their prices, a tip unlocks nothing, and former subscribers are shown how to cancel |

Tests that need a bundled model skip when it's missing. The 3 Gemma tests take about 40 s, so
add `-skip-testing:SooFunnyTests/GemmaEngineTests` for a quick run. The StoreKit purchase tests
skip where the Simulator's local App Store isn't reachable (seen on the iOS 26.4 iPad
simulator); they pass on the iPhone simulator and from Xcode.

---

## Project layout

```
SooFunny/
  App/SooFunnyApp.swift            App entry point and the Color / Words / Books / Math tabs
  Engine/                          Coloring pages
    PixelImage.swift                 RGBA bitmaps
    LabImage.swift                   Lab color and Kuwahara smoothing
    SubjectMask.swift                Apple Vision subject detection
    ImageSegmenter.swift             Picture → blocks and outlines, and the renderer
    ColoringSession.swift            Fill colors, undo, Magic / Real / Clear
  Views/                           Color tab, coloring screen, Settings, shared title
  Showcase/                        Gallery photos (CC0), credits.json and the gallery model
  Samples/SampleArt.swift          Built-in drawings, drawn in code
  Words/                           Word list (kids_words.txt), word browser, Speech
  Words/Photos/                    Word photos (CC0 / public domain) and word_photo_credits.json
  Assistant/                       Talking buddy: Gemma via llama.cpp, listening, prompts
  Voice/                           Natural voice: phonemizer, Kokoro via ONNX Runtime, player
    Resources/                       Pronunciation dictionary, phoneme table, Heart voice
  Books/                           Story books, scanning and text recognition, the reader, audiobooks
  Math/                            Question maker, sessions, progress, and the Math screens
  Sports/                          Summer and winter sports in English and Chinese, and the Sports screens
  Store/                           Tip jar, Support screen, grown-up check, .storekit
  Lab/                             Research Lab benchmarks and screen
  PrivacyInfo.xcprivacy            Privacy manifest
SooFunnyTests/                     Unit tests
scripts/
  build_llama.sh                   Builds llama.cpp for iOS
  fetch_model.sh                   Downloads and checks Gemma and Kokoro
  build_voice_lexicon.py           Rebuilds the pronunciation dictionary from misaki
  make_icon.py                     Makes the app icon from design/soo-icon.png
design/soo-icon.png                App icon artwork
docs/images/                       README screenshots and the Sports animation GIF
marketing/                         The 2-minute presentation, demo videos (iPhone 16, iPad), the Sports animations clip and the introduction slides (PDF)
AppStore/LISTING.md                App Store listing, review notes, submission checklist
PRIVACY.md                         Privacy policy
project.yml                        XcodeGen project definition
```

---

## Changing content

- **Words:** edit `SooFunny/Words/kids_words.txt`. It has blank-line-separated sections, each
  starting with `Category: <name> | <emoji>`, then one word per line with an optional
  `| <emoji>`. Run the tests afterwards; they check the format and that every word can be
  spoken.
- **Gallery photos:** add a JPEG (about 1024 px) to `SooFunny/Showcase/` named
  `<group>-<name>.jpg`, and add an entry with title, author, license and source URL to
  `credits.json`. Use only photos you're allowed to bundle (the current set is all CC0). Check
  how it looks as a coloring page; busy photos make busy pages.
- **Word photos:** `python3 scripts/find_word_photos.py <folder>` searches Wikimedia Commons
  for CC0 and public-domain photos for every word, and `--sheets` makes contact sheets to
  review them. Record the chosen photo (or `null`) for each word in
  `scripts/word_photo_picks.json`, and up to two more for the buddy screen in
  `scripts/word_photo_extras.json`, then run `python3 scripts/bundle_word_photos.py`. Check
  every photo by eye: search results include unsuitable pictures.
- **Story books:** edit `StoryLibrary` in `SooFunny/Books/StoryBooks.swift`. Each book has an
  id, title, cover emoji, color and pages (an emoji scene and the text); set `language: .chinese`
  for a Chinese book. Use only text you're allowed to share.
- **App icon:** replace `design/soo-icon.png`, then run `python3 scripts/make_icon.py`.
- **Pronunciation dictionary:** to rebuild it from newer misaki data, run
  `python3 scripts/build_voice_lexicon.py <folder with us_gold.json, us_silver.json, tokenizer.json>`.
- **Version:** change `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.

---

## Releasing on the App Store

Everything needed is in **[AppStore/LISTING.md](AppStore/LISTING.md)**: name, subtitle,
description, keywords, age rating, the tip setup, App Privacy answers ("Data Not
Collected"), notes for App Review, screenshot sizes, and a step-by-step checklist.

In short:

1. **Developer Program:** join it.
2. **App Store Connect agreements:** accept the Paid Apps Agreement and add banking and tax
   details.
3. **Create the app and the tips** with the IDs above.
4. **Archive a Release build** with your Team ID and upload it.
5. **Test on TestFlight** with a Sandbox account.
6. **Submit** for review.

**Status:** version 0.2 (build 3), with the Books tab, and the yearly subscription were approved and
[released on the App Store](https://apps.apple.com/us/app/soofunny/id6827777441) on November 6, 2026.
Version 0.3 (build 5), with the Sports tab and everything free with optional tips, was submitted
to App Review on November 13, 2026, with the three tips.

---

## Performance

Measured on an **iPhone 16** (optimized build) unless noted.

| What | Time |
|---|---|
| Voice: word prepared in advance, or said before | 0–6 ms |
| Voice: new word | about 0.65 s |
| Voice: first phrase of a buddy answer | about 1.1 s |
| Voice: model load at launch (in the background) | about 0.4 s |
| Voice: generation speed | about 2× faster than real time |
| Buddy: Gemma introduction (simulator on a Mac) | about 5 s |
| Coloring page from a photo (iPad simulator on a Mac) | 0.06–0.3 s |

Older devices, such as the iPad 10th generation, are slower, but prepared speech still plays
right away.

---

## Known limitations

- **App size:** about 918 MB, because both AI models are bundled for offline use.
- **The buddy:** a 1-billion-parameter model gives simple answers and can be wrong; the app says
  so. It knows only the word, not its picture.
- **Listening:** recognizing children's voices hasn't been tuned with real children yet. Devices
  that can't recognize English on the device can't listen; typing works instead.
- **The voice:** no offline voice is truly indistinguishable from a person yet. Words with
  several readings ("read") use their most common one, and the buddy's word highlighting is an
  estimate.
- **Coloring pages:** very busy photos (crowds, rocks, foliage) make busy pages; **Big blocks**
  helps. Subject detection needs a real device; the Simulator doesn't run it.
- **Scanned books:** text recognition can misread handwriting, stylized fonts or busy pages;
  grown-ups can fix the words before saving. Chinese uses Apple's voice, not the natural one.
- **Research Lab:** Apple's on-device language model needs Apple Intelligence (iOS 26+,
  supported devices only).

---

## Credits and licenses

SooFunny's own code, word list, artwork and text: © 2026 Soo X Intelligence LLC. All rights
reserved. Bundled third-party parts keep their own licenses:

| Component | Use | License |
|---|---|---|
| [Gemma 3 1B](https://ai.google.dev/gemma) (GGUF by [unsloth](https://huggingface.co/unsloth/gemma-3-1b-it-GGUF)) | Talking buddy | [Gemma Terms of Use](https://ai.google.dev/gemma/terms) |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | Runs Gemma | MIT |
| [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) and the "Heart" voice (ONNX by [onnx-community](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX)) | Natural voice | Apache-2.0 |
| [misaki](https://github.com/hexgrad/misaki) dictionaries | Pronunciation | Apache-2.0 |
| [ONNX Runtime](https://github.com/microsoft/onnxruntime-swift-package-manager) | Runs Kokoro | MIT |
| Gallery photos from [Wikimedia Commons](https://commons.wikimedia.org/) | Color tab | CC0; photographers listed in Settings → Photo credits and `credits.json` |
| Word photos from [Wikimedia Commons](https://commons.wikimedia.org/) | Words tab | CC0 or public domain; listed in Settings → Photo credits and `word_photo_credits.json` |
| App icon "Soo" artwork | Icon | Provided by the developer |

Apple frameworks used: SwiftUI, StoreKit 2, Vision, VisionKit, Speech, AVFoundation, PhotosUI and, in the
Research Lab, FoundationModels.

Design references: the Words tab and Research Lab follow the design of the Android app
[frankdu/hack_android_base](https://github.com/frankdu/hack_android_base). No code, word list or
images were copied from it.

---

<p align="center">Made with ❤️ for curious kids by <a href="https://www.chengjianglong.com/">Chengjiang Long</a> · © 2026 Soo X Intelligence LLC</p>
