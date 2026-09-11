# Choose your APK

Download [Campus Wi-Fi v1.3.1](https://github.com/rohityadav-sas/pcampus-login/releases/tag/v1.3.1). All four APKs use the same release signing key, version 1.3.1 / code 5, and distinct package IDs. They can coexist, but enable automatic login in only one variant while comparing them.

## Recommended order to try

| Order | APK | Branch / package | When to choose it |
| --- | --- | --- | --- |
| 1 | `Campus-WiFi-v1.3.1-root.apk` | `root` / `wifi.login.root` | Rooted phone with Magisk/su. Kernel event listener, no permanent notification. |
| 2 | `Campus-WiFi-v1.3.1-foreground.apk` | `permanent-notification` / `wifi.login.foreground` | Recommended non-root option if a permanent notification is acceptable. |
| 3 | `Campus-WiFi-v1.3.1-legacy.apk` | `main` / `wifi.login.auto` | Android 6-14; legacy connectivity broadcasts, no permanent notification. |
| 4 | `Campus-WiFi-v1.3.1-modern.apk` | `android-15` / `wifi.login.android15` | Modern target without a permanent notification. Best-effort callbacks depend on process lifetime; Android can kill or freeze it. |

This is a practical recommendation, not a reliability benchmark. Root and foreground variants passed repeated reconnect tests on a rooted Android 11 / MIUI phone. The Modern live-callback fix passed background login tests there. Android 7 and Android 15/16 runtime tests and reboot recovery remain unverified. All variants have minimum API 23; the three newer approaches target API 36. Legacy targets API 23 and is blocked by normal Android 15/16 installation.

## Start using a variant

Install the APK, open it, enter credentials, enable automatic login and Save. Allow notifications (including Android 13+ notification permission), floating alerts, and MIUI autostart as appropriate. Login requires a campus Wi-Fi address in 10.100.x.x. No variant waits for Android's authentication-required banner.

Root additionally requires granting su access and an Android `ip monitor` command with wlan interface names. Disable automatic login and Save before uninstalling Root to stop its helper. Root recovery after reboot has not yet been tested. For a fair comparison, disable other installed variants.

All variants retain HTTPS encryption but deliberately disable certificate verification for the fixed campus portal. Credentials stay in each app's private data; settings are not shared between package IDs. No signing keys or credentials are included in release assets.

## Updates and source

These release APKs update earlier release builds of the same package when signed with the same key. Separate `.debug` packages remain separate installations. Back up your release key; a new key cannot update an existing installation.

The release includes SHA256SUMS.txt and SOURCE-COMMITS.txt. Variant source tags are `v1.3.1-legacy`, `v1.3.1-modern`, `v1.3.1-foreground`, and `v1.3.1-root`. The combined release tag `v1.3.1` points to main; the other APKs come from their respective variant tags.

All four installed apps display the same name: **Campus Wi-Fi**. Package IDs and release filenames distinguish the variants. Version 1.3.1 only standardizes launcher names; login behavior is unchanged.
