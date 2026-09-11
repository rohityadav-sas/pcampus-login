<img src="assets/header.svg" width="100%" alt="Campus Wi-Fi animated wave banner">

<p align="center">
  <img src="https://img.shields.io/badge/Android-native-3DDC84?logo=android&amp;logoColor=white" alt="Native Android">
  <img src="https://img.shields.io/badge/Java-17-167568" alt="Java 17">
  <img src="https://img.shields.io/badge/Build-Windows%20terminal-0078D4" alt="Windows terminal build">
  <a href="https://github.com/rohityadav-sas/pcampus-login/actions/workflows/build-apk.yml"><img src="https://github.com/rohityadav-sas/pcampus-login/actions/workflows/build-apk.yml/badge.svg" alt="Android build"></a>
</p>

A small native app for signing in to the Pulchowk campus Wi-Fi portal. Enter your credentials on your phone, choose automatic or one-tap login, and save. No Android Studio, web build service, root or Magisk module is required.

## 🎬 Demo

<p align="center"><a href="assets/demo.mp4"><img src="assets/demo.gif" width="280" alt="Campus Wi-Fi connection demo"></a></p>

[Watch the original MP4](assets/demo.mp4). The GIF is a compact preview of the supplied recording.

## ✨ What it does

- **Automatic login:** reacts to Wi-Fi/network events and a campus `10.100.x.x` address. A brief callback handles events that arrive before the IP. No periodic polling or permanent service.
- **One tap:** opening the configured app signs in and closes after success. On Android 7.1+, long-press the launcher icon → **Settings** to edit saved values.
- **Manual Login:** available beside the saved configuration, with a clear error screen, Retry and Back.
- **Notifications:** “Signing in…” becomes success or failure in the same notification. Sound and floating banners depend on phone settings; quick responses may replace progress before it is visible.
- **Native UI:** centered form, keyboard-safe layout and no input autofocus.

## 🪟 Build on Windows

Use Windows 10/11 x64 with internet access. After cloning this repository—or downloading and extracting its ZIP—open PowerShell in the project folder.

Prepare the toolchain once:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Then build a debug APK:

```powershell
.\apk.ps1 -Debug
```

The first build may download Gradle and build dependencies. Later builds reuse the local caches.

Debug APK output:

```text
app/build/outputs/apk/debug/app-debug.apk
```

Useful commands:

```powershell
.\apk.ps1                  # Debug build
.\apk.ps1 -Debug           # Debug build
.\apk.ps1 -Install         # Debug build + install on an authorized ADB device
.\apk.ps1 -Debug -Install  # Same, explicitly selecting Debug
.\apk.ps1 -Release         # Signed release build; requires release signing setup
.\apk.ps1 -Release -Install
```

For a first release, create a private release signing identity once:

```powershell
.\setup-keys.ps1
```

This creates a PKCS12 release keystore under `signing/` and the local `keystore.properties` used by Gradle. Both are ignored by Git. Back up the keystore and its password securely; future releases must use the same signing identity.

The setup script reuses a complete compatible JDK (17–24) or installs Oracle JDK 21, configures `JAVA_HOME` and `ANDROID_HOME`, installs the current Android CLI when needed, and installs only missing Android SDK components required by this project. The bundled Gradle wrapper is used; no global Gradle installation is required.

## 📱 Compatibility and setup

**This is a GitHub sideload build, not a Google Play release.** It retains target API 23 to preserve the tested legacy connectivity broadcasts. The supported source baseline is Android 6–14; real-device testing has been on Android 11 / MIUI. Other OEM behavior is not verified. Android 15+ blocks normal installation of apps targeting below API 24. Raising the target alone would change automatic-login delivery; modern Android support needs a separate implementation and testing.

1. Install the APK and open it once.
2. Enter your campus username/password and enable **Automatic login**, or leave it off for one-tap mode.
3. Save. On MIUI, allow **Autostart**, notifications, sound and floating notifications in system settings. MIUI may reset Autostart after an update.
4. Connect to campus Wi-Fi. The app identifies the network by its IP range, not its SSID, and does not wait for “Authentication required.”

No campus IP means no request. “No Internet” does not suppress login. DHCP, weak signal, Android broadcast delivery and portal timeouts can delay it. The app avoids duplicate attempts; it does not continuously refresh an expired portal session while you remain connected.

The debug package is separate (`wifi.login.auto.debug`). Stable release builds use `wifi.login.auto`; the original repository's `wifi.login` app is a different package.

## 🔐 Privacy and release signing

Credentials are entered on-device, stored in private app preferences with Android backup disabled, and sent only to the fixed campus portal over HTTPS. They are **not encrypted separately from app-private storage**. Root or a compromised device can read them. There is no analytics or credential-injection build workflow.

The campus uses a private certificate. The app remembers the certificate fingerprint on first use and checks it subsequently. First-use enrollment must happen on a trusted campus network; it is not independent proof of campus identity.

See [release signing and publishing](docs/RELEASING.md). Debug CI artifacts are test builds. Keep release keys private and preserve the same signing identity for updates.

## 🧭 Project map

| Path | Purpose |
| --- | --- |
| `app/src/main/java/wifi/login/auto/` | Native UI, login, receivers and notifications |
| `app/src/main/AndroidManifest.xml` | Permissions and app components |
| `setup.ps1` | Windows toolchain setup/repair |
| `setup-keys.ps1` | One-time private release signing setup |
| `apk.ps1` | Debug/release build with optional device installation |
| `assets/` | Demo recording, GIF and animated banner |
| `docs/` | Release and verification notes |
| `.github/workflows/` | Windows CI build and downloadable debug artifact |

## 🧪 Verification

See [verification and template audit](docs/VERIFICATION.md) for the exact checks and their limits. Contributions should follow [CONTRIBUTING.md](CONTRIBUTING.md).

### Platform references

- [Android 15 minimum target requirement](https://developer.android.com/about/versions/15/behavior-changes-all#minimum-target-api-level)
- [Android 7 connectivity broadcast changes](https://developer.android.com/about/versions/nougat/android-7.0-changes#bg-opt)
- [Android Gradle Plugin 8.13 compatibility](https://developer.android.com/build/releases/agp-8-13-0-release-notes)
