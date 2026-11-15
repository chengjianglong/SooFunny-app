# SooFunny: App Store listing and submission checklist

Everything to enter in App Store Connect for version 0.4, plus the steps only the account
holder can do.

## App information

| Field | Value |
|---|---|
| Name | SooFunny |
| Subtitle (30) | Color, words, books & more |
| Bundle ID | com.chengjianglong.soofunny |
| SKU | soofunny-ios-001 |
| Primary category | Education |
| Secondary category | Entertainment |
| Age rating | 4+ (answer "None" to every content question; no unrestricted web access) |
| Copyright | © 2026 Soo X Intelligence LLC. All rights reserved. |
| Privacy Policy URL | https://github.com/chengjianglong/SooFunny-app/blob/main/PRIVACY.md |
| Support URL | https://www.chengjianglong.com/ |
| Version | 0.4 (build 9): English, 中文 or Bilingual on every tab, and the Qwen buddy. 0.3 (build 5, free with tips and the Sports tab) was released on November 14, 2026 |

Kids Category: not joined. Apple requires a parental gate before purchases in Kids Category
apps, and tips no longer have one (the App Store's Face ID or password check is the only step),
so joining would mean adding the gate back. Outside links still have one; there are no ads, no
analytics and no data collection. Joining it puts the app in the Kids
section but asks you to pick an age band (5 and Under, or 6–8) and triggers stricter review.

## Promotional text (170)

Learn in English, 中文 or both! Color any photo, explore 754 words with a talking buddy, hear books read aloud, do math and discover 51 sports, offline and ad-free.

## Description

SooFunny turns learning into play, and it all works without the internet.

COLOR ANYTHING
Pick a picture of animals, faces, people or the great outdoors, or snap your own photo.
SooFunny turns it into a clean coloring page with smooth outlines. Tap or swipe to fill the
blocks, try Magic colors, or peek at the real photo.

ENGLISH, 中文 OR BOTH
Every part of SooFunny works in English, in Chinese, or in both together. Tap the globe button
to switch at any time. In Bilingual, everything is shown and read aloud in English first and
then in Chinese, so children can learn the two languages side by side.

WORDS WITH A TALKING BUDDY
Explore 754 words in 32 groups, from Animals to Feelings, in English and Chinese. Hear every word, tap its
letters, then ask the talking buddy anything: "What does a lion eat?" The buddy answers out
loud with each word highlighted as it's read, in English, Chinese or both, using an AI model
that runs right on your device.

BOOKS READ ALOUD
Ten picture books, from The Three Little Pigs to Tang poems, read aloud with each word lighting
up as it's read. Scan your own books with the camera or pick pages from Photos: SooFunny reads
the words on the page, in English, Chinese or both, and can turn the whole book into an
audiobook to listen to anytime.

MATH FUN
Flashcards and quizzes for adding, taking away, times and sharing. Choose the numbers to
practice, beat the clock, collect stars, and watch your progress grow.

SPORTS IN TWO LANGUAGES
Discover 51 summer and winter sports, from swimming to snowboarding. Each one has its English
and Chinese name, a short introduction read aloud in both languages, and a playful animation to
watch.

MADE FOR FAMILIES
• Works offline: perfect for car rides and flights
• No ads, no tracking, no accounts
• Nothing leaves your device
• Grown-up check before outside links

FREE FOR EVERY FAMILY
Every picture, word, book, sport and math game is free, with no locks, no subscriptions and no
ads. If your family enjoys SooFunny, you can leave an optional tip in Settings to help keep it
maintained and add new things to learn. Tips are one-time and unlock nothing.

Privacy Policy: https://github.com/chengjianglong/SooFunny-app/blob/main/PRIVACY.md
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

## Keywords (100)

kids,coloring,learn english,vocabulary,read aloud,story books,chinese,math facts,flashcards,offline

## What's New (0.4)

Learn in English, Chinese or both! Tap the new globe button (or go to Settings) to use every
tab in English, 中文 or Bilingual 双语. In Bilingual, English comes first and then Chinese, on
screen and read aloud.

• All 754 words now have Chinese, and every story book can be read in either language or both.
• The talking buddy is smarter, especially in Chinese, and can talk and listen in Chinese.
• Talk about any sport with the talking buddy, and sports now read themselves aloud as soon as
  you open one. The Sports tab moves next to Words.
• Math questions and cheers in Chinese too.
• Leaving a tip is quicker.

## Tips (In-App Purchases → Consumables)

Create three consumables (they must match the app exactly). Each needs a review screenshot:
the Support SooFunny screen, after the grown-up check (`screenshots/review-tips.png`, taken from
an Xcode run, which uses `SooFunny.storekit`; new tips can take a while to reach the sandbox).

| Reference name | Product ID | Price (USA) | Display name | Description |
|---|---|---|---|---|
| Tip Small | com.chengjianglong.soofunny.tip.small | $1.99 | Small tip | A small thank-you that helps keep SooFunny going. |
| Tip Medium | com.chengjianglong.soofunny.tip.medium | $4.99 | Medium tip | A thank-you that helps add new things to learn. |
| Tip Large | com.chengjianglong.soofunny.tip.large | $9.99 | Large tip | A big thank-you that keeps SooFunny free for all. |

Let Apple set equivalents for other countries.

**The old subscription** (`com.chengjianglong.soofunny.premium.yearly`, $19.99 a year): once 0.3
is out, remove it from sale in Subscriptions → SooFunny Premium Yearly → Availability, so nobody
new can subscribe. Existing subscribers keep it until they cancel; the app shows them how.

## App Privacy ("nutrition label")

Choose **Data Not Collected**. The app has no analytics, ads, accounts or servers; photos,
scanned book pages, voice, model conversations and progress never leave the device. Tips are handled by Apple.

## Notes for App Review

SooFunny works fully offline. The talking buddy (Words → sparkle button) runs the
Qwen 2.5 1.5B Instruct model (Apache-2.0) on the device with llama.cpp; nothing is sent to a
server. It answers in English, Chinese or both, following the app's language setting. Chinese
listening uses SpeechAnalyzer on the device; the first Chinese conversation asks iOS to download
Apple's Mandarin dictation model (no audio or text leaves the device).

The Books tab reads story books aloud. "Scan a book" uses the camera (VisionKit document
scanner), and the text on each page is recognized on the device with Apple's Vision framework;
English and Chinese are read by on-device natural voices (Kokoro, with a choice of five Chinese voices in Settings).

The Sports tab (free) introduces 51 summer and winter sports in English and Chinese, each with
a looping animation drawn in code. "Talk about …" on a sport opens the same on-device buddy,
which is given that sport's introduction to keep its answers accurate.

New in 0.4: a language switch (the globe button at the top of each tab, or Settings → Language)
shows and reads every tab in English, Chinese, or both. The talking buddy now uses Qwen 2.5 1.5B
on the device and answers in the chosen language.

Since 0.3, every feature is free; nothing is locked. The three In-App Purchases are optional
tips (consumables) that unlock nothing: Settings (gear) → Support SooFunny → Leave a tip. The
App Store's purchase sheet confirms each tip with Face ID or the account password. Outside links
are behind a parental gate that asks a two-digit multiplication question (for example
"What is 14 × 7?"). Former subscribers see a
"Manage subscription" button in Settings to cancel the old subscription.

## Screenshots needed

- iPhone 6.9" display (1320 × 2868 or 1290 × 2796): 3 to 10
- iPad 13" display (2064 × 2752 or 2048 × 2732): 3 to 10

In App Store Connect only the iPhone 6.3" (1206 × 2622, `screenshots/iphone-6.3/`) and iPad 13"
sets are used; 0.3 has 10 of each, ending with the Sports grid and a sport's page.

Suggested shots: Sports (a sport's animation and introduction), Color gallery, a photo turned into a coloring page and half colored, Words
category grid, the talking buddy conversation, a story book being read aloud, Math quiz with a
✓, Progress Reports.

## Checklist: account holder only

These need your Apple Account, identity, bank and tax details, so they can't be done for you.

1. Enroll in the Apple Developer Program as an individual ($99/year):
   https://developer.apple.com/programs/enroll/ (use the Apple Account that will own the app).
2. In App Store Connect → Business: accept the **Paid Apps Agreement**, add **bank account** and
   **tax forms** (W-9 for the US). In-App Purchases can't be sold until these are active.
3. In Xcode → Settings → Accounts, sign in with that Apple Account so builds can be signed for
   distribution. Note your Team ID (Membership page).
4. In App Store Connect → Apps → "+": create **SooFunny** with the bundle ID above.
5. Create the tips exactly as in the table above, and submit them with the build.

## Checklist: build and upload

1. `./scripts/build_llama.sh` and `./scripts/fetch_model.sh` (the model is bundled; the upload is
   about 1.2 GB, well under the 4 GB limit).
2. Archive with your Team ID: Product → Archive in Xcode (or `xcodebuild archive` with
   `DEVELOPMENT_TEAM=<Team ID>`), then Distribute App → App Store Connect.
3. Test with TestFlight on a real device: leave a tip with a Sandbox account.
4. Fill in the listing above, attach the build and the tips, and submit for review.
