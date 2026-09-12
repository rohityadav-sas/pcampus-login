<img src="assets/header.svg" width="100%" alt="Campus Wi-Fi banner">

<p align="center">
  <img src="https://img.shields.io/badge/Android-native-3DDC84?logo=android&amp;logoColor=white" alt="Native Android">
  <img src="https://img.shields.io/badge/Java-17-167568" alt="Java 17">
  <img src="https://img.shields.io/badge/Build-Windows%20PowerShell-0078D4" alt="Windows PowerShell build">
</p>

A native Android app for signing in to the Pulchowk campus Wi-Fi portal.

## Download the app

[Download v1.3.1](https://github.com/rohityadav-sas/pcampus-login/releases/tag/v1.3.1)

Choose the APK that fits your phone. Try them in this order:

| # | APK | Best For | Branch / Package |
|:-:|-----|----------|-------------------|
| 1 | `Campus-WiFi-v1.3.1-root.apk` | 🔓 **Rooted devices** with Magisk/su. No permanent notification. | `root`<br>`wifi.login.root` |
| 2 | `Campus-WiFi-v1.3.1-foreground.apk` | ⭐ **Recommended for non-root users.** Requires a permanent notification. | `permanent-notification`<br>`wifi.login.foreground` |
| 3 | `Campus-WiFi-v1.3.1-legacy.apk` | 📱 **Android 6–14.** Uses older Wi-Fi connection broadcasts. No permanent notification. | `main`<br>`wifi.login.auto` |
| 4 | `Campus-WiFi-v1.3.1-modern.apk` | 📱 **Android 15+** Uses network callbacks with a one-shot wake-up subscription. No permanent notification | `android-15`<br>`wifi.login.android15` |

> **Note:** Start with option 2 on non-rooted phones. On **Xiaomi/MIUI**, enable **Autostart**, set battery usage to **No restrictions**, and allow notifications. Background restrictions can affect all variants, but option 4 is especially vulnerable to process killing or freezing. If automatic login stops, reopen the app.

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
.\setup-environment.ps1
```

The first setup can take several minutes because Java and Android SDK files may need to be downloaded and extracted. The script reads `compileSdk` and an optional Build Tools pin from the app, and uses the latest Android command-line tools. Without a pin, Android Gradle Plugin selects its compatible Build Tools version.

The scripts find the Android application module automatically. A project with more than one application module can select one with `-Module app` or a Gradle path such as `-Module :mobile`. This option works with `setup-environment.ps1`, `apk.ps1`, and `update-icon.ps1`.

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
signing\key.p12
keystore.properties
```

These files are private and are ignored by Git.

**Important:** keep `key.p12` and its password backed up somewhere safe.

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

### 6. Build a Release AAB

For Google Play or another store that accepts Android App Bundles, run:

```powershell
.\apk.ps1 -Aab
```

The signed AAB will be at:

```text
app\build\outputs\bundle\release\app-release.aab
```

GitHub releases should continue using the Release APK because Android cannot install an AAB directly.

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
| `.\setup-environment.ps1` | Sets up Java and the Android SDK |
| `.\setup-keys.ps1` | Creates the private release signing key once |
| `.\apk.ps1` | Builds a Debug APK |
| `.\apk.ps1 -Debug` | Builds a Debug APK |
| `.\apk.ps1 -Release` | Builds the signed Release APK |
| `.\apk.ps1 -Aab` | Runs tests and release lint, then builds a signed Release AAB |
| `.\apk.ps1 -Install` | Builds Debug and installs it on a connected phone |
| `.\apk.ps1 -Release -Install` | Builds Release and installs it on a connected phone |

## 🎨 Change the app icon

1. Add your icon to `assets/icon/`. SVG and PNG are supported.
2. If using PNG, it must be **1024 × 1024 pixels**. Keep the artwork centered, with minimal empty space around it. Color and transparency are supported.
3. Choose the icon format to build with:

```powershell
   .\apk.ps1 -Release -Icon png
   .\apk.ps1 -Release -Icon svg
```

   - If only one icon file is present, you can simply run `.\apk.ps1 -Release`.
   - If both are present and `-Icon` is not specified, the script will prompt you to choose one.

## 📱 Using the app

1. Install the APK and open the app.
2. Enter your campus username and password.
3. Turn on **Automatic login** if you want the app to sign in automatically.
4. Save the settings.
5. Connect to campus Wi-Fi.

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

The app checks whether the phone has `10.100.x.x` IP address and if it matches, the app sends the login request.

Login can sometimes be delayed by:

- slow DHCP
- weak Wi-Fi
- Android background restrictions
- phone manufacturer power-saving features
- a slow campus portal response

## ⚠️ Android compatibility

The app supports installation from Android 6 to 14. This **Legacy** variant listens for Wi-Fi connection broadcasts and has no permanent notification.

Android 15 and newer normally block installation of apps with this old target unless the user bypasses that restriction. Background restrictions may still delay or prevent automatic login.

## 🔐 Privacy and security

Your campus username and password are entered and stored on your phone.

They are stored inside the app's private data area. Android backup is disabled.

The app does not include analytics or send your credentials to another service.

## 🧪 Contributing

For contribution information, see [CONTRIBUTING.md](CONTRIBUTING.md).

### Platform references

- [Android 15 minimum target requirement](https://developer.android.com/about/versions/15/behavior-changes-all#minimum-target-api-level)
- [Android 7 connectivity broadcast changes](https://developer.android.com/about/versions/nougat/android-7.0-changes#bg-opt)
- [Android Gradle Plugin 8.13 compatibility](https://developer.android.com/build/releases/agp-8-13-0-release-notes)
