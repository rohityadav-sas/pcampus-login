<img src="assets/header.svg" width="100%" alt="Campus Wi-Fi animated wave banner">

<p align="center">
  <img src="https://img.shields.io/badge/Android-native-3DDC84?logo=android&amp;logoColor=white" alt="Native Android">
  <img src="https://img.shields.io/badge/Java-17-167568" alt="Java 17">
  <img src="https://img.shields.io/badge/Build-Windows%20terminal-0078D4" alt="Windows terminal build">
  <a href="https://github.com/rohityadav-sas/pcampus-login/actions/workflows/build-apk.yml"><img src="https://github.com/rohityadav-sas/pcampus-login/actions/workflows/build-apk.yml/badge.svg" alt="Android build"></a>
</p>

A small native app for signing in to the Pulchowk campus Wi-Fi portal.

## 🎬 Demo

<p align="center"><a href="assets/demo.mp4"><img src="assets/demo.gif" width="280" alt="Campus Wi-Fi connection demo"></a></p>

[Watch the original MP4](assets/demo.mp4). The GIF is a compact preview of the supplied recording.

## ✨ What it does

- **Automatic-login mode:** reacts to Wi-Fi/network events and a campus `10.100.x.x` address. A brief callback handles events that arrive before the IP. No periodic polling or permanent service.
- **One-tap mode:** opening the app signs in and closes after success. On Android 7.1+, long-press the launcher icon → **Settings** to edit saved values.
- **Manual Login:** available inside the app.

## 🪟 Build on Windows

Use Windows with internet access.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\apk.ps1
```

This single command checks the toolchain, installs missing tools into your user profile, verifies SDK licenses, runs lint and builds a debug APK. The first run downloads the SDK, JDK if needed, Gradle and build dependencies; later runs reuse them.

```text
app/build/outputs/apk/debug/app-debug.apk
```

Other commands:

```powershell
.\setup-environment.ps1       # Only prepare the toolchain
.\apk.ps1 -Install            # Build, then install on an authorized ADB device
.\apk.ps1 -SkipSetup          # Build with an already prepared toolchain
.\apk.ps1 -Release            # Requires your private signing configuration
```

The setup script reuses a complete compatible JDK (17–24) or downloads Oracle JDK 21 with checksum verification. It installs the Android SDK **only** in `%LOCALAPPDATA%\Android\Sdk`, reports download progress and accepts SDK licenses automatically.

## 📱 Compatibility and setup

**This is a GitHub sideload build, not a Google Play release.** It retains target API 23 to preserve the tested legacy connectivity broadcasts. The supported source baseline is Android 6–14; real-device testing has been on Android 11 / MIUI. Other OEM behavior is not verified. Android 15+ blocks normal installation of apps targeting below API 24. Modern Android support needs a separate implementation and testing.

1. Install the APK and open it once.
2. Enter your campus username/password and enable **Automatic login**, or leave it off for one-tap mode.
3. Save. On MIUI, allow **Autostart**, notifications, sound and floating notifications in system settings. MIUI may reset Autostart after an update or reinstall.

The debug package is separate (`wifi.login.auto.debug`). Stable release builds use `wifi.login.auto`.

## 🔐 Privacy and release signing

Credentials are entered on-device, stored in private app preferences with Android backup disabled, and sent only to the fixed campus portal over HTTPS.

See [release signing and publishing](docs/RELEASING.md). Debug CI artifacts are test builds. Keep release keys private and preserve the same signing identity for updates.

## 🧭 Project map

| Path | Purpose |
| --- | --- |
| `app/src/main/java/wifi/login/auto/` | Native UI, login, receivers and notifications |
| `app/src/main/AndroidManifest.xml` | Permissions and app components |
| `setup-environment.ps1` | Windows toolchain bootstrap |
| `apk.ps1` | Lint/build with optional installation |
| `assets/` | Demo recording, GIF and animated banner |
| `docs/` | Release and verification notes |
| `.github/workflows/` | Build verification and downloadable debug artifact |

## 🧪 Verification

See [verification and template audit](docs/VERIFICATION.md) for the exact checks and their limits. Contributions should follow [CONTRIBUTING.md](CONTRIBUTING.md).

### Platform references

- [Android 15 minimum target requirement](https://developer.android.com/about/versions/15/behavior-changes-all#minimum-target-api-level)
- [Android 7 connectivity broadcast changes](https://developer.android.com/about/versions/nougat/android-7.0-changes#bg-opt)
- [Android Gradle Plugin 8.13 compatibility](https://developer.android.com/build/releases/agp-8-13-0-release-notes)
