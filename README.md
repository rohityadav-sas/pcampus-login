<img src="assets/header.svg" width="100%" alt="Campus Wi-Fi banner">

<p align="center">
  <img src="https://img.shields.io/badge/Android-native-3DDC84?logo=android&amp;logoColor=white" alt="Native Android">
  <img src="https://img.shields.io/badge/Java-17-167568" alt="Java 17">
  <img src="https://img.shields.io/badge/Build-Windows%20PowerShell-0078D4" alt="Windows PowerShell build">
</p>

A native Android app for signing in to the Pulchowk campus Wi-Fi portal.

## Download the app

[Download v1.3.1 - four signed APKs](https://github.com/rohityadav-sas/pcampus-login/releases/tag/v1.3.1)

Try **Root** first if your phone is rooted; otherwise start with **Permanent Notification**. Next try **Legacy (Android 6-14)**, or **Modern** if you need a newer target without a permanent notification. Modern remains best-effort when Android kills/freezes its process.

See [the APK comparison and setup guide](docs/DOWNLOADS.md) for package names, requirements, tested behavior, updates and source tags. This order is a recommendation, not a measured reliability ranking.

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

Replace `assets/icon/icon.svg`, then build with `./apk.ps1 -Release` (or `./apk.ps1` for debug). The build automatically regenerates the launcher resources. No Android Studio or image tools are needed.

Use a simple SVG containing paths with a `viewBox="0 0 width height"`. Fill/stroke colors (`#RGB`, `#RRGGBB`, `none`), stroke width, caps and joins are supported. Convert text/shapes to paths and flatten groups, transforms and styles before saving. Separate SVG arc flags with spaces, as in the supplied icon. Unsupported elements/attributes stop generation with an explanation.

To generate resources manually before using Gradle directly, run `./update-icon.ps1`. To change the white background, edit the default `$Background` in that script. Generated resources include the older Android icon, adaptive icon and Android 13+ themed icon. Install the rebuilt APK to see the change; some launchers cache icons until restarted.

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

The app checks whether the phone has `10.100.x.x` IP address and if it matches, the app sends the login request.

Login can sometimes be delayed by:

- slow DHCP
- weak Wi-Fi
- Android background restrictions
- phone manufacturer power-saving features
- a slow campus portal response

## ⚠️ Android compatibility

The app currently targets Android API 23 on purpose.

This is kept for the older connectivity-broadcast behavior used by the automatic-login feature.

The main supported range is Android 6 through Android 14.

The app has mainly been tested on Android 11 / MIUI, so behavior may differ on other phones.

Android 15 and newer normally block installation of apps that target below API 24. Supporting newer Android versions properly may require changes to the automatic-login system, not only changing the target SDK number.

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
