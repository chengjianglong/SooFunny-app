# SooFunny: App Store listing and submission checklist

Everything to enter in App Store Connect for version 0.1, plus the steps only the account
holder can do.

## App information

| Field | Value |
|---|---|
| Name | SooFunny |
| Subtitle (30) | Color, words & math for kids |
| Bundle ID | com.chengjianglong.soofunny |
| SKU | soofunny-ios-001 |
| Primary category | Education |
| Secondary category | Entertainment |
| Age rating | 4+ (answer "None" to every content question; no unrestricted web access) |
| Copyright | © 2026 Soo X Intelligence LLC. All rights reserved. |
| Privacy Policy URL | https://github.com/chengjianglong/SooFunny-app/blob/main/PRIVACY.md |
| Support URL | https://www.chengjianglong.com/ |
| Version | 0.1 (build 1) |

Kids Category: optional. SooFunny already follows its rules (parental gate before purchases and
outside links, no ads, no analytics, no data collection). Joining it puts the app in the Kids
section but asks you to pick an age band (5 and Under, or 6–8) and triggers stricter review.

## Promotional text (170)

Color any photo, explore 754 words with a friendly talking buddy, and practice math, all
offline and ad-free.

## Description

SooFunny turns learning into play, and it all works without the internet.

COLOR ANYTHING
Pick a picture of animals, faces, people or the great outdoors, or snap your own photo.
SooFunny turns it into a clean coloring page with smooth outlines. Tap or swipe to fill the
blocks, try Magic colors, or peek at the real photo.

WORDS WITH A TALKING BUDDY
Explore 754 English words in 32 groups, from Animals to Feelings. Hear every word, tap its
letters, then ask the talking buddy anything: "What does a lion eat?" The buddy answers out
loud with each word highlighted as it's read, using an AI model that runs right on your
device.

MATH FUN
Flashcards and quizzes for adding, taking away, times and sharing. Choose the numbers to
practice, beat the clock, collect stars, and watch your progress grow.

MADE FOR FAMILIES
• Works offline: perfect for car rides and flights
• No ads, no tracking, no accounts
• Nothing leaves your device
• Grown-up check before purchases and links

SOOFUNNY PREMIUM
Try every feature free: color 14 gallery pictures, the drawings and 15 of your own photos;
explore three word groups and talk with the buddy about every animal; and practice all four
operations (times and sharing with the numbers 1 to 5). Premium unlocks every picture and
unlimited own photos, all 32 word groups, the talking buddy for every word, and times and
sharing with every number. Start with a 7-day free trial, then $19.99 a year. Family Sharing is
included.

Payment is charged to your Apple Account when the trial ends. The subscription renews
automatically each year unless it's turned off at least 24 hours before the end of the
current period. Manage or cancel anytime in your Apple Account settings.

Privacy Policy: https://github.com/chengjianglong/SooFunny-app/blob/main/PRIVACY.md
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

## Keywords (100)

kids,coloring,color by tap,learn english,vocabulary,math facts,flashcards,preschool,offline,AI

## What's New (0.1)

First release: coloring gallery, word explorer with a talking buddy, and Math Fun.

## Subscription (In-App Purchases → Subscriptions)

| Field | Value |
|---|---|
| Subscription group | SooFunny Premium |
| Reference name | SooFunny Premium Yearly |
| Product ID | com.chengjianglong.soofunny.premium.yearly (must match the app exactly) |
| Duration | 1 year |
| Price | $19.99 (USA); let Apple set equivalents for other countries |
| Introductory offer | Free trial, 1 week, new subscribers |
| Family Sharing | On |
| Display name | SooFunny Premium |
| Description | Every picture, all words, the talking buddy and × ÷ math. |
| Review screenshot | The subscription screen (after the grown-up check) |

## App Privacy ("nutrition label")

Choose **Data Not Collected**. The app has no analytics, ads, accounts or servers; photos,
voice, model conversations and progress never leave the device. Purchases are handled by Apple.

## Notes for App Review

SooFunny works fully offline. The talking buddy (Words → sparkle button) runs Google's
Gemma 3 1B model on the device with llama.cpp; nothing is sent to a server.

Premium features (locked items show a lock): the sixth Animals photo, own photos/camera after
15 free pictures, word groups beyond Animals, Colors and Numbers, the talking buddy outside
Animals, and × ÷ with focus numbers above 5 in Math. Purchases and outside
links are behind a parental gate that asks a two-digit multiplication question (for example
"What is 14 × 7?").

Subscribe: Settings (gear) → Get SooFunny Premium → answer the gate → choose the plan.
Restore Purchases is in Settings and on the subscription screen.

## Screenshots needed

- iPhone 6.9" display (1320 × 2868 or 1290 × 2796): 3 to 10
- iPad 13" display (2064 × 2752 or 2048 × 2732): 3 to 10

Suggested shots: Color gallery, a photo turned into a coloring page and half colored, Words
category grid, the talking buddy conversation, Math quiz with a ✓, Progress Reports.

## Checklist: account holder only

These need your Apple Account, identity, bank and tax details, so they can't be done for you.

1. Enroll in the Apple Developer Program as an individual ($99/year):
   https://developer.apple.com/programs/enroll/ (use the Apple Account that will own the app).
2. In App Store Connect → Business: accept the **Paid Apps Agreement**, add **bank account** and
   **tax forms** (W-9 for the US). Subscriptions can't be sold until these are active.
3. In Xcode → Settings → Accounts, sign in with that Apple Account so builds can be signed for
   distribution. Note your Team ID (Membership page).
4. In App Store Connect → Apps → "+": create **SooFunny** with the bundle ID above.
5. Create the subscription exactly as in the table above, and submit it with the first build.

## Checklist: build and upload

1. `./scripts/build_llama.sh` and `./scripts/fetch_model.sh` (the model is bundled; the upload is
   about 830 MB, well under the 4 GB limit).
2. Archive with your Team ID: Product → Archive in Xcode (or `xcodebuild archive` with
   `DEVELOPMENT_TEAM=<Team ID>`), then Distribute App → App Store Connect.
3. Test with TestFlight on a real device: subscribe with a Sandbox account, restore, cancel.
4. Fill in the listing above, attach the build and the subscription, and submit for review.
