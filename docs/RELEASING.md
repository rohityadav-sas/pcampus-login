# Release checklist

This repository distributes APKs through GitHub, not Google Play. The legacy target SDK is intentional; do not raise it without redesigning and testing background event delivery.

## First release only

1. Run `.\setup.ps1` to prepare Java and the Android SDK.
2. Run `.\setup-keys.ps1`.
   - It creates `signing/release.p12`.
   - The keystore type is PKCS12.
   - It uses an RSA 3072-bit key.
   - It creates `keystore.properties` automatically.
   - Use a strong password and store it securely.
3. Back up `signing/release.p12` and its password somewhere separate from the repository.

The release signing identity is permanent for this distribution channel. Future APK updates must be signed with the same key.

## Every release

1. Build and test the separate debug package with:

   ```powershell
   .\apk.ps1 -Debug
   .\apk.ps1 -Debug -Install
   ```

2. Build the signed release APK:

   ```powershell
   .\apk.ps1 -Release
   ```

3. Install/test it if needed:

   ```powershell
   .\apk.ps1 -Release -Install
   ```

4. Verify the release APK with the Android SDK's `apksigner verify --verbose`.
5. Increase `versionCode` before publishing an update.
6. Attach the signed APK and its SHA-256 digest to an intentional GitHub release.

Debug APKs are test builds, not stable distribution releases. This checkout currently has no CI workflow.

The release package is `wifi.login.auto`. Debug builds use `wifi.login.auto.debug`, so debug and release installations remain separate.

Never commit `keystore.properties`, `signing/`, signing passwords, private keys, prebuilt APKs, or device preferences.

## Published variants

See [DOWNLOADS.md](DOWNLOADS.md) for the four v1.3.0 APKs, source tags, recommendation order and runtime limits. Build each branch with the same private release key. Verify package, version, signature and SHA-256 before uploading.
