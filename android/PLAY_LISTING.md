# SooFunny on Google Play: listing and submission checklist

What to enter in Play Console for the first Android release (0.4, version code 4), plus the
steps only the account holder can do. Settled choices: app ID `com.chengjianglong.soofunny`
(it can never change after the first upload), no purchases or tips in the first release, and
target ages 5 and under, 6–8 and 9–12.

## Create the app (Play Console → Create app)

| Field | Value |
|---|---|
| App name (30) | SooFunny |
| Default language | English (United States) – en-US |
| App or game | App |
| Free or paid | Free (this can't be changed to paid later) |
| Declarations | Accept the Developer Program Policies and US export laws |

## Main store listing

**Short description (80):**

Color photos, learn words, hear books & do math in English, 中文 or both. Ad-free.

**Full description (4000):**

SooFunny turns learning into play, and it all works without the internet.

COLOR ANYTHING
Pick a picture of animals, faces, people or the great outdoors, or take your own photo.
SooFunny turns it into a clean coloring page with smooth outlines. Tap to fill the blocks, try
Magic colors, or peek at the real photo.

ENGLISH, 中文 OR BOTH
Every part of SooFunny works in English, in Chinese, or in both together. Tap the globe button
to switch at any time. In Bilingual, everything is shown and read aloud in English first and
then in Chinese, so children can learn the two languages side by side.

WORDS WITH A TALKING BUDDY
Explore 754 words in 32 groups, from Animals to Feelings, in English and Chinese. Hear every
word, tap its letters, then ask the talking buddy anything: "What does a lion eat?" The buddy
answers out loud with each word highlighted as it's read, using an AI model that runs right on
your device. (The buddy's model is a one-time 1.1 GB download that a grown-up starts.)

BOOKS READ ALOUD
Ten picture books, from The Three Little Pigs to Tang poems, read aloud with each word lighting
up as it's read. Add your own books from the camera or from photos: SooFunny reads the words on
the page, in English, Chinese or both, and can turn the whole book into an audiobook.

MATH FUN
Flashcards and quizzes for adding, taking away, times and sharing. Choose the numbers to
practice, beat the clock, collect stars, and watch your progress grow.

SPORTS IN TWO LANGUAGES
Discover 51 summer and winter sports, from swimming to snowboarding. Each one has its English
and Chinese name, a short introduction read aloud in both languages, and a playful animation.

MADE FOR FAMILIES
• Works offline: perfect for car rides and flights
• No ads, no purchases, no tracking, no accounts
• Nothing your child makes or says leaves the device
• Grown-up check before downloads, sharing and reports

**Graphics:**

| Asset | Requirement | Status |
|---|---|---|
| App icon | 512 × 512 PNG, 32-bit, up to 1 MB | to make from the launcher icon |
| Feature graphic | 1024 × 500 JPEG or 24-bit PNG | to make |
| Phone screenshots | 2–8, 9:16, at least 1080 px on the short side is best | to take |
| 7" and 10" tablet screenshots | up to 8 each (needed to show as tablet-ready) | to take |

Suggested shots, as on iOS: a photo turned into a coloring page half colored, the Color
gallery, the Words grid, the talking buddy, a book being read aloud, a Math quiz, a sport's
animation, Bilingual mode.

**Category:** Education. **Tags:** Education, Kids, Language learning (pick from Play's list).
**Contact email:** required and shown publicly; the app's Settings → About shows
chengjiang.long@gmail.com. **Website:** https://www.chengjianglong.com/

## App content (Policy → App content)

- **Privacy policy:** https://github.com/chengjianglong/SooFunny-app/blob/main/PRIVACY.md
  (it now has an "On Android" section).
- **Ads:** No, the app does not contain ads.
- **App access:** All functionality is available without special access.
- **Content rating (IARC questionnaire):** Category "Reference, News, or Educational". Answer
  No to violence, fear, sexuality, language, controlled substances, gambling and crude humor.
  Users interact or share content with other users: **No**. Shares the user's location: **No**.
  Allows purchases of digital goods: **No**. If asked about AI-generated content: **Yes**, an
  on-device chatbot that answers questions about words and sports for children, with a Report
  button on each answer. Expected rating: Everyone / PEGI 3 / USK 0.
- **Target audience and content:** Ages **5 and under, 6–8, 9–12**. This puts the app under the
  Families policy (below). Answer that the store listing could appeal to children: Yes.
- **News app:** No. **COVID-19 tracing:** No. **Government app:** No. **Financial features:**
  None. **Health:** None. **Data safety:** below.

## Data safety

Google counts data as collected only when it leaves the device, so SooFunny collects and shares
nothing:

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | (not asked when nothing is collected) |
| Do you provide a way for users to request that their data is deleted? | (not asked) |

Why it's true, for your own check:
- Photos, scanned pages, colored pictures, audiobooks, voice, buddy conversations, settings and
  math progress stay in the app's own storage. Sharing or saving happens only through Android's
  share sheet or to Pictures/SooFunny, when the user chooses it.
- Speech recognition is on-device only (`createOnDeviceSpeechRecognizer`); the app never falls
  back to an online recognizer.
- ML Kit (text recognition, document scanner, subject segmentation) runs on the device. Its
  usage-logging components (`datatransport`) are removed in the manifest, as is ONNX Runtime's
  telemetry. Google Play services may download ML Kit models; that's Google's own service.
- The only network use is downloading the buddy's model from huggingface.co after a grown-up
  check. No user data is sent with it.
- "Report" on a buddy answer opens the user's own email app with the answer filled in; nothing is
  sent unless the user sends that email. Email you receive is not data the app collects.

## Families policy check

- No ads and no ad or analytics SDKs. ML Kit and ONNX Runtime don't collect data as configured.
- Permissions: camera use goes through the system camera app (no CAMERA permission), photos
  through the system photo picker (no storage permission), microphone (RECORD_AUDIO) only when
  the child taps Talk, internet only for the buddy's model. No location, contacts or accounts.
- Grown-up check (a two-digit multiplication) before the model download, sharing an audiobook
  and reporting an answer.
- Generative AI: Play's AI-generated content policy asks for a way to report offensive output
  in the app. Each buddy answer has a Report button. The model's system prompt keeps it to
  child-friendly answers about the word or sport.

## Release: build, sign and upload

1. Make the upload key once (it asks for a password; back up `android/upload-key.jks` and the
   password, as every update must be signed with it):
   `cd android && ./tools/make_upload_key.sh`
2. Build the bundle (the voices asset pack is included):
   `./gradlew :app:bundleRelease` → `app/build/outputs/bundle/release/app-release.aab`
   (about 345 MB; Play's limit for a bundle with asset packs is well above that).
3. In Play Console → Test and release → Setup → App signing: use **Google-generated app signing
   key** (Play App Signing). Upload the `.aab` to a testing track.
4. **New personal developer accounts must run a closed test first:** at least 12 testers opted
   in for 14 days in a row before you can apply for production access. Add testers by email list
   (Testing → Closed testing → Testers), share the opt-in link, and have them keep it installed.
5. Then apply for production (Dashboard → Apply for production), answer the questions about the
   test, and roll out.

## Checklist: account holder only

1. Verify your identity and (for a personal account) your Android device in Play Console.
2. Run `./tools/make_upload_key.sh` and keep the key and password safe.
3. Create the app and fill in everything above.
4. Recruit 12+ closed testers for 14 days.
5. Make the 512 px icon, feature graphic and screenshots (I can take screenshots from the
   emulator and draft the graphics if you want).
