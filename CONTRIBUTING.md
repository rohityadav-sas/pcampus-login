# Contributing

Use native Android components, Java 17 and the Gradle wrapper. Keep the launch path small: no WebView, Compose, trackers or framework dependencies just for styling. Run `./apk.ps1` before proposing changes.

Preserve the native form, safe system-bar/keyboard insets, no autofocus, one-tap close-on-success behavior, event-based login and notification replacement. Do not add polling. Test connection-before-IP, repeated events, timeout/retry, saved credentials and notification actions on a real device.

Use synthetic credentials for tests. The portal uses a private certificate: keep pin verification, and do not replace it with a trust-all connection. First-use pin enrollment is trust-on-first-use; only enroll on a trusted campus network.
