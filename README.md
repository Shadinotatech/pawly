# Pawly – Pet Care Tracker (Android app)

Flutter-e banano offline pet care tracker: tika (vaccine), oshudh (medicine) reminder, repeat care (flea, deworming), ojon-er chart, vet visit note.
Ei folder-e puro app-er code ache. App ta GitHub Actions (free) diye cloud-e build hoy, tai apnar computer-e kono programming tool install korte hobe na.

## Ki ki ache

| Folder / file | Ki |
| --- | --- |
| `lib/` | App-er sob code (Dart / Flutter) |
| `android/` | Android setting, icon, notification permission |
| `.github/workflows/build.yml` | Cloud-e APK ar AAB build korar niyom |
| `docs/privacy-policy.html` | Privacy policy page (Play Store-e lagbe) |
| `store/` | Play Store icon (512), feature graphic, listing text ar form-er uttor |
| `test/` | Choto test |

Signing key (`upload-keystore.jks`) ei zip-e **nei**; seta alada zip-e dewa hoyeche. Seta kokhono GitHub-e upload korben na.

---

## Apnake ja korte hobe (step by step)

### Dhap 1: GitHub-e code rakhun (10 minute)
1. https://github.com e free account khulun (thakle login korun).
2. Upore dane **+** > **New repository**. Nam: `pawly`. **Public** select korun. **Create repository**.
3. Notun repo page-e **"uploading an existing file"** link-e click korun.
4. `pawly.zip` unzip korun. Unzip kora `pawly` folder-er **bhitorer sob kichu** (`.github`, `android`, `docs`, `lib`, `store`, `test`, `tools`, `pubspec.yaml`, ityadi) browser-e tene (drag) chere din.
5. Niche **Commit changes** chapun.

### Dhap 2: Signing key-er 4 ta secret din (5 minute)
1. Repo-te **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.
2. `pawly-signing.zip`-er `SIGNING-KEY-INFO.txt` khule 4 ta secret ekta ekta kore banan:
   - `KEYSTORE_BASE64` = `KEYSTORE_BASE64.txt` file-er puro lekha (copy-paste)
   - `KEYSTORE_PASSWORD` = info file-e lekha password
   - `KEY_ALIAS` = `upload`
   - `KEY_PASSWORD` = info file-e lekha password (eki password)

### Dhap 3: App build korun (15 minute, nijei hoy)
1. Repo-te **Actions** tab > (prothom bar hole sobuj button chepe enable korun) > bame **Build Pawly** > dane **Run workflow** > **Run workflow**.
2. 10-15 minute opekkha korun. Sobuj tik ✓ hole run-e click korun.
3. Niche **Artifacts** theke duita file namaben:
   - `pawly-apk` → bhitore `app-release.apk` (nijer phone-e install kore test korar jonno)
   - `pawly-aab-for-play-store` → bhitore `app-release.aab` (Play Store-e upload korar jonno)
4. Lal ✗ hole: failed step khule error lekha copy kore amake pathan, ami thik kore dibo.

### Dhap 4: Phone-e test korun
1. `app-release.apk` phone-e pathan (Google Drive / USB), khulun, "unknown apps install" allow korun.
2. 2 ta pet add korun chobi shoho, kichu tika / oshudh / ojon din, Settings > **Send a test notification** chepe dekhun notification ashe kina.
3. 4-8 ta screenshot nin (Today, pet profile, oshudh, tika, ojon chart, Add menu).

### Dhap 5: Privacy policy online korun (5 minute)
1. Repo-te `docs/privacy-policy.html` khulun > pencil (edit) icon > `YOUR-EMAIL@example.com` (2 jaygay) bodle **apnar email** likhun > **Commit changes**.
2. **Settings** > **Pages** > Source: **Deploy from a branch** > Branch: `main`, folder: `/docs` > **Save**.
3. 2-3 minute por link hobe: `https://APNAR-GITHUB-NAME.github.io/pawly/privacy-policy.html`. Browser-e khule dekhe nin.

### Dhap 6: Google Play Console (apnake nijei korte hobe)
1. https://play.google.com/console e developer account khulun ($25 ekbar), **Personal** account, identity verification (NID / passport) shesh korun.
2. **Create app**: nam `Pawly: Pet Care & Vet Tracker`, App, Free.
3. `store/STORE-LISTING.md` theke title, short description, full description copy-paste korun. Icon: `store/play-icon-512.png`, feature graphic: `store/feature-graphic-1024x500.png`, ar apnar screenshot.
4. **App content**-er sob form (privacy policy URL, ads: No, data safety: No data collected, content rating, target audience 18+) `STORE-LISTING.md`-er uttor onujayi puron korun.
5. **Testing > Closed testing** > track banan > **Create release** > `app-release.aab` upload korun. Play App Signing chaile **Google-ke manage korte din** (default).
6. **Testers**-e 15-20 jon-er Gmail din (bondhu, poribar). Tader opt-in link pathan; sobai yeno 14 din app install rakhe.
7. 14 din por **Apply for production** > review pass hole app live.

### Notun version dite chaile
`pubspec.yaml`-e `version: 1.0.0+1` ke `1.0.1+2` korun (+ er porer number protibar barate hobe), commit korun; Actions nije notun AAB banabe.

---

## Jinish gulo jene rakhun
- Signing key harale app update dewa kothin hoy. `pawly-signing.zip` Google Drive-e ar ekta USB-te rakhun.
- Package ID: `com.pawlyapp.pawly` (Play Store-e ekbar dile ar bodlano jay na).
- Version 1.0-e ad ba payment nei; review shohoje pass korbe. Pro subscription ar backup v1.1-e jog hobe.
