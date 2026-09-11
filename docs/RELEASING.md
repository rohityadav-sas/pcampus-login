# Release checklist

This repository distributes APKs through GitHub, not Google Play. The legacy target SDK is intentional; do not raise it without redesigning and testing background event delivery.

1. Run `./apk.ps1` and device tests with the separate debug package.
2. Copy `keystore.properties.example` to `keystore.properties` and supply your existing signing identity. Both the properties and signing files are ignored.
3. For a first distribution only, create a key with `keytool -genkeypair -keystore signing/release.jks -alias release -keyalg RSA -keysize 3072 -validity 10000`. Create the `signing` directory first. Let keytool prompt for passwords; never put them in a command, workflow input, or source file.
4. Back up the key and passwords securely. Every update must use the same key and a greater versionCode.
5. Run `./apk.ps1 -Release`. Verify the APK with the SDK's `apksigner verify --verbose` and test it before publishing.
6. Attach the signed APK and its SHA-256 digest to an intentional GitHub release. CI debug artifacts are for testing, not stable distribution.

The release package is `wifi.login.auto`, preserving the finished local app's identity. The original repository app used `wifi.login` and is a separate installation. A debug APK uses `wifi.login.auto.debug` and never replaces either app. Existing phone credentials are not copied into debug builds.

Never commit signing keys, credentials, prebuilt APKs, or device preferences. Old repository history and previously published artifacts are not rewritten or deleted by this replacement.
