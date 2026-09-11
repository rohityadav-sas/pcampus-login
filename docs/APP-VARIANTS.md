# App variants and signing

| Branch | Release package | Debug package |
| --- | --- | --- |
| main | wifi.login.auto | wifi.login.auto.debug |
| android-15 | wifi.login.android15 | wifi.login.android15.debug |
| permanent-notification | wifi.login.foreground | wifi.login.foreground.debug |
| root | wifi.login.root | wifi.login.root.debug |

All variants disable certificate verification for the fixed campus HTTPS endpoint.
The local worktrees use copies of the same existing private release keystore and signing configuration. These files remain ignored and are not uploaded to GitHub. When cloning elsewhere, supply that same key and keystore.properties; do not generate a new key for each variant. Debug builds use the machine's standard Android debug key, separate from the release identity.

No PowerShell scripts were changed for this configuration. Distinct package IDs let the apps coexist, with separate settings and permissions.
