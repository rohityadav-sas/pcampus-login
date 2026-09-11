# Root-assisted experiment

Separate app: wifi.login.root.debug (Campus Wi-Fi Root). Main branch is unchanged.

Uses a root-owned blocking `ip monitor address` listener and an explicit privileged broadcast to the app. No polling and no foreground service notification. Signing-in and result notifications remain. Root must be granted; MIUI autostart must be enabled. Reboot recovery uses the existing boot receiver and requires Magisk to retain the grant; reboot recovery has not yet been tested.

Disable Automatic login and Save before uninstalling: this stops the root helper. Files live under /data/local/tmp/wifi.login.root.debug. This test supports the phone's wlan interface naming and Android ip command. It is not yet a broadly validated root distribution.

Build: .\apk.ps1

Verified debug build and lint. Repeated Wi-Fi reconnection with the app in the background successfully logs in on the connected Android 11 MIUI phone. Fixed inherited FIFO stdin causing SELinux denial when invoking am; each broadcast now reads /dev/null.
