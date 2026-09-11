# Verification and template audit

## Campus Login

- Windows PowerShell 5.1 compatibility has been considered in the setup/build scripts, including native-process stderr handling.
- Gradle wrapper 8.14.3 / Android Gradle Plugin 8.13.2 are pinned by the repository.
- Debug builds use the separate `wifi.login.auto.debug` package.
- Release builds require a private signing configuration and fail early when it is missing.
- New release identities are created with `setup-keys.ps1` as PKCS12 keystores using an RSA 3072-bit key.
- Private signing material is local-only and ignored by Git.
- Verified on September 12, 2026: `setup.ps1` succeeds in Windows PowerShell 5.1 with the existing local toolchain; debug assembly, debug lint, and signed release assembly pass. Android SDK `apksigner verify --verbose` confirms the release APK's v1 and v2 signatures.
- This checkout currently has no GitHub Actions workflow. No current clean-runner build is claimed.

Version 1.2 targets API 36. Certificate verification is deliberately disabled for the fixed campus endpoint; its trust-manager lint suppressions are scoped to that implementation. Remaining lint warnings concern English programmatic text and attributes ignored on older devices.

## Current build workflow

```powershell
.\setup.ps1
.\apk.ps1 -Debug
.\apk.ps1 -Install
```

For the first signed release only:

```powershell
.\setup-keys.ps1
.\apk.ps1 -Release
```

## Limits

The owner reports successfully verifying setup in Oracle VirtualBox. Agent-side setup checks reused installed tools. Earlier CI attempts used the previous SDK installer and cannot validate the current Android CLI setup.

A live campus login requires campus Wi-Fi and valid credentials and is not performed by CI.

Version 1.2 debug assembly, debug lint and signed release assembly pass. The connected Android 11 phone rejected debug APK installation with INSTALL_FAILED_USER_RESTRICTED, so no live result is claimed for the new event path. Android 7 and Android 15/16 runtime tests remain pending.

Device acceptance checks: enable automatic login and allow notifications; connect to campus Wi-Fi without waiting for Android validation; confirm progress then success replaces the same notification. Repeat after ordinary process termination, reboot and package upgrade. Disable automatic login and confirm no automatic request occurs. Check unrelated Wi-Fi, denied notifications, manual login, retries and system-bar/keyboard insets. Use ordinary process termination for the wake-up test, not Force stop, which intentionally blocks background execution until the next app launch.

## Android-15 branch reconnect fix

Confirmed on the connected Android 11 device: process remained alive while Android released the PendingIntent registration five seconds after delivery. Added a separate live callback, attached on app launch and wake-up receipt; re-arm the one-shot on disconnection without a delivery/re-registration loop. Release build and lint pass; installed update and confirmed background login without reopening the app. This does not guarantee delivery after process death/freezing, and Android 15/16 runtime validation remains pending. PowerShell scripts unchanged.
