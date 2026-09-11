# Choose your APK

Download [Campus Wi-Fi v1.3.1](https://github.com/rohityadav-sas/pcampus-login/releases/tag/v1.3.1).

## Recommended order to try

| # | APK | Best For | Branch / Package |
|:-:|-----|----------|-------------------|
| 1 | `Campus-WiFi-v1.3.1-root.apk` | 🔓 **Rooted devices** with Magisk/su. No permanent notification. | `root`<br>`wifi.login.root` |
| 2 | `Campus-WiFi-v1.3.1-foreground.apk` | ⭐ **Recommended for non-root users.** Requires a permanent notification. | `permanent-notification`<br>`wifi.login.foreground` |
| 3 | `Campus-WiFi-v1.3.1-legacy.apk` | 📱 **Android 6–14.** Uses older Wi-Fi connection broadcasts. No permanent notification. | `main`<br>`wifi.login.auto` |
| 4 | `Campus-WiFi-v1.3.1-modern.apk` | 📱 **Android 15+** Uses network callbacks with a one-shot wake-up subscription. No permanent notification | `android-15`<br>`wifi.login.android15` |

> **Note:** Start with option 2 on non-rooted phones. On Xiaomi/MIUI, enable Autostart (or Background autostart), set battery usage to No restrictions, and allow notifications, floating notifications, and sound. Background restrictions can affect all variants, but option 4 is especially vulnerable to process killing or freezing. If automatic login stops, reopen the app.
