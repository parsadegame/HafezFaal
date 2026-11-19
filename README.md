# فال حافظ — Offline Android App

A fully offline Persian Hafez fortune-telling app. All 495 poems and their
interpretations are embedded in the APK — no internet connection is used.

## APK

- Download the signed APK from the **Releases** page of this repository.
- Source build: `build/HafezFaal.apk`
- Package: `com.hafez.faal`
- Version: 1.6 (versionCode 7) — shown as «۱٫۶» under the title and in the footer
- Size: ~0.72 MB
- SHA-256: `B14F3F6A124A5BFF96F9F7728829071874EB5250AAF61EB2AF1EA946089F03B2`

## Features

- Starts with only the «فال بگیر» button and a short prompt; pressing it shows
  a random poem and its interpretation, which rise into view with a short
  animation.
- A poem can also be chosen manually from the menu; the poem stays hidden
  until either action.
- Warm parchment background with a subtle geometric star pattern and gold
  accents.
- The interpretation (تفسیر) of every poem is shown under the poem.
- 495 poems, all with interpretations, embedded from the
  [HafezFaalDatabase](https://github.com/mahmoud-eskandari/HafezFaalDatabase).
- **Hamburger menu** (☰, top corner) opens a slide-out list of all 495 poems.
- **Font-size control lives at the top of that menu** (`− ۲۱ +`); the poem and
  the interpretation both use exactly the same size, and it is remembered
  between launches.
- Picking a poem in the menu closes it, shows that poem and scrolls to it.
- The phone's back button closes the menu instead of exiting the app.
- Persian UI, right-to-left, with bundled **Amiri** (poetry) and
  **Vazirmatn** (interface) fonts.
- Works completely offline; the app has no INTERNET permission.

## Android 10+ compatibility

- `minSdkVersion 21` (Android 5.0) so it installs on Android 10 and newer.
- `targetSdkVersion 34` (safe for Android 10–15; avoids forced edge-to-edge).
- `android:exported="true"` on the launcher activity (required on Android 12+).
- `configChanges` prevents the page reloading when the device rotates or
  switches dark mode.
- Light status/navigation bars with dark icons.
- Local WebView file access enabled so bundled fonts and assets load.

## Install on your phone

1. Copy `HafezFaal-v1.6.apk` to the phone (USB, Google Drive, etc.).
2. Open the file on the phone.
3. If prompted, allow "Install unknown apps" for the app you are opening it
   with (Files/Chrome), then tap **Install**.
4. Open the app. Under the title «فال حافظ» you must see «۱٫۶»; the footer also
   says «نسخهٔ ۱٫۶». If you still see two font buttons and no hamburger menu,
   Android is still launching the old app.

Version 1.6 uses the same signing key as 1.1–1.5, so it can be installed over
those directly. If version **1.0** is installed (the original build), uninstall
it first (Settings → Apps → فال حافظ → Uninstall), because 1.0 used a different
key and Android will otherwise fail with "App not installed".

Or with `adb`:

```sh
adb uninstall com.hafez.faal   # only needed if version 1.0 is installed
adb install HafezFaal-v1.6.apk
adb shell am start -n com.hafez.faal/.MainActivity
```

The APK is signed with a debug key (the same key as 1.1–1.6), which is fine for
sideloading. Publishing to Google Play requires a release keystore.

The signing key is **not committed** to this repository. `build-apk.ps1` creates
`keystore/hafez-debug.keystore` on the first build and reuses it afterwards, so
your own rebuilds remain updateable in place. Keep that file if you care about
updating over an installed copy.

## Rebuild

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build-apk.ps1
```

Requirements:

- JDK 17 or newer (set `JAVA_HOME`, or let the script find an installed JDK)
- Android SDK with build-tools `36.0.0` and platform `android-37.0`
  (set `ANDROID_HOME`, or use the standard SDK location)
- `adb` only if you want to install from a cable

Set `ANDROID_HOME` / `JAVA_HOME` if the script cannot find the tools. The
script accepts `-Sdk`, `-BuildToolsVersion`, `-Platform`, and `-JdkHome`
parameters as overrides.

The build uses the SDK tools directly (`aapt2` → `javac` → `d8` → `zipalign`
→ `apksigner`); Gradle is not required.

After building, verify the page logic (menu contents, poem selection, and that
the font control scales both poem and interpretation):

```sh
node tests/page-test.js
```

## Project layout

```
HafezFaalOffline/
├── build-apk.ps1                 # full APK build script
├── embed-poems.ps1               # injects data/faals.json into the HTML
├── tests/page-test.js            # runs the page JS and checks the menu/font logic
├── data/faals.json               # source poem database (495 poems)
├── templates/hafez-faal.template.html
├── app/src/main/
│   ├── AndroidManifest.xml
│   ├── java/com/hafez/faal/MainActivity.java
│   ├── res/layout/activity_main.xml
│   ├── res/values/strings.xml
│   ├── res/values/styles.xml
│   ├── res/drawable/ic_launcher.png
│   └── assets/
│       ├── hafez-faal.html       # generated: template + embedded poems
│       └── fonts/                # Amiri + Vazirmatn
└── build/HafezFaal.apk           # output
```

To update the poem database, replace `data/faals.json` and rebuild; the
`embed-poems.ps1` step re-embeds it automatically.
