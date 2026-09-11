# Contributing

Use native Android components, Java 17 and the Gradle wrapper. Keep the launch path small: no WebView, Compose, trackers or framework dependencies just for styling. Run `./apk.ps1` before proposing changes.

Preserve the native form, safe system-bar/keyboard insets, no autofocus, one-tap close-on-success behavior, event-based login and notification replacement. Do not add polling. Test connection-before-IP, repeated events, timeout/retry, saved credentials and notification actions on a real device.

Use synthetic credentials for tests. Certificate verification is deliberately disabled for the fixed campus endpoint. Keep that TLS configuration scoped to this endpoint.
