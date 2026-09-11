# Verification and template audit

## Campus Login

- Windows PowerShell 5.1: setup completed and verified SDK licenses; existing JDK and SDK reused.
- Gradle wrapper 8.14.3 / Android Gradle Plugin 8.13.2: debug and signed release APK builds, debug/release lint passed.
- Setup validation checks: missing Java path, non-JDK path, valid compiler-equipped JDK and unsupported Java ceiling.
- Release key used only locally; ignored signing files verified. No credentials or keystores included in Git.
- Debug application ID is separate to preserve the user's installed app and credentials. ADB installation was attempted but the phone rejected it with INSTALL_FAILED_USER_RESTRICTED (Install canceled by user); no fresh device UI verification is claimed.
- Supplied MP4 converted to a compact GIF; both live under assets. Header animation is local SVG, with a static fallback if a viewer disables animation.

Warnings intentionally remain for trust-on-first-use certificate pinning, English-only programmatic text, and a manifest attribute ignored by Android 6. The synchronous first-use pin write is on a worker thread. Target API 23 is intentional and documented; only that obsolete-target lint rule is disabled, not all lint.

## kotlin-template findings and fixes

- `apk.ps1` previously built release and installed unconditionally: a clean clone needed private signing files and a connected phone. Default is now debug build; Release and Install are explicit.
- Paths previously depended on the current working directory. Scripts now enter their own repository directory.
- JDK validation now requires `javac`, checks the process exit code and caps the runtime to the selected wrapper's supported range. Discovery also searches common installation directories.
- JDK fallback now verifies its published SHA-256. Downloads allow enough time for a large archive and reject incomplete content lengths.
- License validation now checks a second invocation after acceptance, rather than treating the initial unaccepted-license prompt as the final state.
- README version labels corrected to the current build configuration.

## Limits

A completely empty Windows VM was not available. The download-and-extract branches were reviewed, not exercised by deleting the user's existing toolchain. Windows CI is supplied as a separate reproducible build check; a green local build is not proof that every fresh Windows/network combination works. A live campus login requires campus Wi-Fi and valid credentials and is not performed by CI.

The kotlin-template debug APK and lint also passed after the script changes.

Original experimental app behavior was tested previously on Android 11. Android 6–14 source compatibility is guarded, but only Android 11 has real-device evidence. Android 15+ normal installation and Google Play are outside this build's scope. No release was uploaded automatically.

