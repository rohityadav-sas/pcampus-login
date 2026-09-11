# Verification and template audit

## Campus Login

- Windows PowerShell 5.1 compatibility has been considered in the setup/build scripts, including native-process stderr handling.
- Gradle wrapper 8.14.3 / Android Gradle Plugin 8.13.2 are pinned by the repository.
- Debug builds use the separate `wifi.login.auto.debug` package.
- Release builds require a private signing configuration and fail early when it is missing.
- New release identities are created with `setup-keys.ps1` as PKCS12 keystores using an RSA 3072-bit key.
- Private signing material is local-only and ignored by Git.
- GitHub Actions performs a Windows debug build from a clean checkout and uploads the debug APK artifact.

Warnings intentionally remain for trust-on-first-use certificate pinning, English-only programmatic text, and the deliberate target API 23 compatibility strategy. Only the obsolete-target lint rule is disabled.

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

A completely empty Windows VM has not been used to exercise every download/install branch end-to-end. The setup script is designed to install or reuse the required toolchain, while GitHub Actions provides a separate clean Windows debug-build check.

A live campus login requires campus Wi-Fi and valid credentials and is not performed by CI.

Real-device behavior has primarily been verified on Android 11 / MIUI. Android 15+ normal installation and Google Play are outside this build's current scope because the app deliberately targets API 23 for legacy connectivity-broadcast behavior.
