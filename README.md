<img src="assets/header.svg" width="100%" alt="Campus Wi-Fi banner">

<p align="center">
  <img src="https://img.shields.io/badge/Android-native-3DDC84?logo=android&amp;logoColor=white" alt="Native Android">
  <img src="https://img.shields.io/badge/Java-17-167568" alt="Java 17">
  <img src="https://img.shields.io/badge/Build-Windows%20PowerShell-0078D4" alt="Windows PowerShell build">
</p>

A native Android app for signing in to the Pulchowk campus Wi-Fi portal.

## Download the app

[Download v1.3.1 - four signed APKs](https://github.com/rohityadav-sas/pcampus-login/releases/tag/v1.3.1)

Choose the APK that fits your phone. Try them in this order:

| # | APK | Best for | Branch / package |
|:-:|-----|----------|------------------|
| 1 | `Campus-WiFi-v1.3.1-root.apk` | Rooted phones with Magisk or `su`; no permanent notification. | `root`<br>`wifi.login.root` |
| 2 | `Campus-WiFi-v1.3.1-foreground.apk` | Non-root phones; keeps a permanent notification to stay active. | `permanent-notification`<br>`wifi.login.foreground` |
| 3 | `Campus-WiFi-v1.3.1-legacy.apk` | Android 6–14; listens for older Wi-Fi connection broadcasts, without a permanent notification. | `main`<br>`wifi.login.auto` |
| 4 | `Campus-WiFi-v1.3.1-modern.apk` | Android 15+; uses network callbacks and a one-time wake-up subscription, without a permanent notification. | `android-15`<br>`wifi.login.android15` |

On Xiaomi/MIUI, enable **Autostart** (or **Background autostart**), set battery use to **No restrictions**, and allow notifications. Background restrictions can affect every variant; the modern variant is especially sensitive to the app being stopped or frozen. Reopen the app if automatic login stops.

Install and enable automatic login in only **one variant at a time**. The APKs have separate settings and can be installed side by side. The release includes `SHA256SUMS.txt` and `SOURCE-COMMITS.txt`; source tags are `v1.3.1-legacy`, `v1.3.1-modern`, `v1.3.1-foreground`, and `v1.3.1-root`. Reboot recovery and Android 15/16 runtime behavior have not been verified for every variant.

## 🎬 Demo

<p align="center">
  <img src="assets/demo.gif" width="280" alt="Campus Wi-Fi login demo">
</p>

## ✨ Modes

- **Automatic-login mode:** when the phone connects to campus Wi-Fi and gets a `10.100.x.x` address, the app tries to sign in automatically.
- **One-tap login mode:** if automatic login is off, open the app to sign in manually.
- **Manual Login button:** you can also start a login from inside the app.
- **Notifications:** the app can show whether login is in progress, successful, or failed.

## 🪟 Build the APK on Windows

This project is designed so a beginner can build it from PowerShell without installing Android Studio. Download and extract the repository ZIP from GitHub's **Code → Download ZIP** menu if Git is not installed; otherwise clone it below.

On a fresh Windows installation, allow the local scripts in the current PowerShell window first:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

This setting ends when you close that window.

### 1. Clone the Repository
```
git clone https://github.com/rohityadav-sas/pcampus-login
```
### 2. Run the setup script

Run:

```powershell
cd pcampus-login
.\setup.ps1
```

The first setup can take several minutes because Java and Android SDK files may need to be downloaded and extracted.

### 3. Build a Debug APK

```powershell
.\apk.ps1 -Debug
```

The first build may also download Gradle and some build dependencies. This is normal and usually happens only once.

When the build finishes, the Debug APK will be at this location:

```text
app\build\outputs\apk\debug\app-debug.apk
```

### 4. Build a release apk

Run:

```powershell
.\setup-keys.ps1
```

You will be asked to enter and confirm a password.

The script creates:

```text
signing\release.p12
keystore.properties
```

These files are private and are ignored by Git.

**Important:** keep `release.p12` and its password backed up somewhere safe.

Use the **same release key** when building all four variants or updating an installed APK. Each variant has its own package name, so they can be installed side by side. Debug builds use a separate package name ending in `.debug` and are for testing.

You only need to run `setup-keys.ps1` once.

### 5. Build the Release APK

After release signing is set up, run:

```powershell
.\apk.ps1 -Release
```

The Release APK will be at this location:

```text
app\build\outputs\apk\release\app-release.apk
```

Before publishing an update, increase `versionCode`, test the release APK, and verify its signature with Android SDK `apksigner`. Keep `keystore.properties`, the `signing/` folder, passwords, and private keys out of Git. Attach the signed APK and its SHA-256 checksum to the GitHub release.

## 📱 Install directly from PowerShell

If you have an Android phone connected with USB debugging enabled, you can build and install in one command.

Debug:

```powershell
.\apk.ps1 -Debug -Install
```

Release:

```powershell
.\apk.ps1 -Release -Install
```

## 🧰 Command summary

| Command | What it does |
| --- | --- |
| `.\setup.ps1` | Sets up Java and the Android SDK |
| `.\setup-keys.ps1` | Creates the private release signing key once |
| `.\apk.ps1` | Builds a Debug APK |
| `.\apk.ps1 -Debug` | Builds a Debug APK |
| `.\apk.ps1 -Release` | Builds the signed Release APK |
| `.\apk.ps1 -Install` | Builds Debug and installs it on a connected phone |
| `.\apk.ps1 -Release -Install` | Builds Release and installs it on a connected phone |

## 🎨 Change the app icon

1. Add your icon to `assets/icon/`. (SVG and PNG are supported)
2. A PNG must be a still image exactly **1024 × 1024 pixels**. Keep the artwork centered, with little empty space around it. Color and transparency are supported.
3. Choose the icon you want:

```powershell
.\apk.ps1 -Release -Icon png
.\apk.ps1 -Release -Icon svg
```

If only one icon file is present, you can simply run `.\apk.ps1 -Release`. If both are present and you do not specify `-Icon`, the script asks you to choose one.

The build updates the icon automatically. To use a different file name, pass `-IconSource path/to/icon.png` instead of `-Icon`. SVG icons need paths and a `viewBox`; complex SVG effects and text are not supported. If you build with Gradle directly, run `.\update-icon.ps1` first. Install the new APK to see the icon; your phone's launcher may cache the old one.

## 📱 Using the app

1. Install the APK and open the app.
2. Enter your campus username and password.
3. Turn on **Automatic login** if you want the app to sign in automatically.
4. Save the settings.
5. Connect to campus Wi-Fi.

If automatic login is off, open the app whenever you want to sign in.

On Android 7.1 and newer, you can long-press the app icon and open **Settings** if the shortcut is available.

### MIUI / Xiaomi phones

MIUI may restrict apps in the background.

If automatic login does not work, allow:

- Autostart
- Notifications
- Floating notifications
- Notification sound, if wanted

MIUI may reset some of these permissions after an app update.

## 📶 How automatic login works

The app keeps a regular Wi-Fi callback while its process lives and also arms a one-shot PendingIntent subscription for wake-up. Android removes the PendingIntent subscription after delivery; the live callback handles repeated reconnects and re-arms it on disconnection. This is best-effort after process death or freezing, without a permanent service. The app checks whether the phone has a `10.100.x.x` IP address and, if it matches, sends the login request immediately. It does not wait for internet validation or an authentication-required event, and does not poll.

Registration is restored when the app opens, after reboot, and after an update. Disabling automatic login removes it. After manually force-stopping the app, open it again to restore background operation. On Android 13+, allow notification permission to see login progress and results.

Login can sometimes be delayed by:

- slow DHCP
- weak Wi-Fi
- Android background restrictions
- phone manufacturer power-saving features
- a slow campus portal response

## ⚠️ Android compatibility

Version 1.2 targets API 36 (Android 16) and retains minimum API 23 (Android 6), including Android 7. It no longer relies on the old manifest connectivity broadcast or requires an outdated-target installation bypass on Android 15/16.

The new background registration uses an API available since Android 6. Builds and lint pass, but live Android 7 and Android 15/16 login tests are still pending. Manufacturer background restrictions can still affect event delivery.

## 🔐 Privacy and security

Your campus username and password are entered and stored on your phone.

They are stored inside the app's private data area. Android backup is disabled.

The app does not include analytics or send your credentials to another service.

HTTPS encryption is retained, but certificate verification and first-use pin enrollment are disabled for the fixed campus endpoint. The app therefore does not authenticate the portal's identity.


## 🧪 Contributing

For contribution information, see [CONTRIBUTING.md](CONTRIBUTING.md).

### Platform references

- [Android 15 minimum target requirement](https://developer.android.com/about/versions/15/behavior-changes-all#minimum-target-api-level)
- [PendingIntent network callbacks](https://developer.android.com/reference/android/net/ConnectivityManager#registerNetworkCallback(android.net.NetworkRequest,%20android.app.PendingIntent))
- [Android Gradle Plugin 8.13 compatibility](https://developer.android.com/build/releases/agp-8-13-0-release-notes)

## Keeping the README in sync across branches

Each branch has its own README. To copy a README change, commit it on one branch and cherry-pick that commit onto the other three. For example, after committing on `main`:

```powershell
$readmeCommit = git rev-parse HEAD
git switch android-15
git cherry-pick $readmeCommit
git switch permanent-notification
git cherry-pick $readmeCommit
git switch root
git cherry-pick $readmeCommit
git switch main
git push origin main android-15 permanent-notification root
```

Commit unrelated work separately, and resolve any conflicts before continuing. Changes to a GitHub release description or its APK files must be made separately.
