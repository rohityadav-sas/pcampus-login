# Change the launcher icon

Place **one** source in `assets/icon/`: `icon.svg` or `icon.png`. Run `./apk.ps1 -Release` (or `./apk.ps1` for debug). Icons regenerate before every build using Windows/.NET; no extra installation is required.

## Select the format directly

```powershell
.\apk.ps1 -Release -Icon png
.\apk.ps1 -Release -Icon svg
.\apk.ps1 -Icon png -Install
```

`-Icon` selects `assets/icon/icon.png` or `assets/icon/icon.svg`, relative to the repository even if you run the script elsewhere. Choices are case-insensitive. `-Image` is an alias (`-Image PNG` also works). This skips the menu even when both files exist. Missing files and invalid formats stop with a short error; there is no fallback.

For a custom filename, use `-IconSource path/to/custom.png` instead. Do not combine `-Icon`/`-Image` with `-IconSource`. Without either argument, the existing automatic selection/menu still applies. The selected image must satisfy the requirements below.

## PNG requirements

- Exactly **1024 x 1024 pixels**, square, saved as a real PNG. Incorrect dimensions stop the build and show the received size.
- A single still image. Animated PNG and renamed JPEG/WebP files are rejected.
- Full color is supported. Transparency is optional; transparent artwork is recommended so the launcher background looks clean. An opaque image keeps its own square background.
- Use centered artwork with little empty margin. The generator adds safe padding; excessive padding in your source makes the icon look small. Do not pre-crop into a circle or rounded square.
- Regular and adaptive icons keep the PNG's colors. No custom monochrome/themed layer is generated from a full-color PNG. Launcher-specific styling may still apply.

Generated older-Android sizes are 48, 72, 96, 144 and 192 pixels, plus a padded 432-pixel adaptive foreground. The default launcher background is white; change `$Background` in `update-icon.ps1` to customize it.

## If both files exist

**Neither takes priority.** The script displays a menu: **1 = SVG**, **2 = PNG**, **Q = cancel**. Invalid answers prompt again; Enter without a choice cancels. To skip the prompt, explicitly choose:

```powershell
.\apk.ps1 -Release -IconSource assets/icon/icon.png
.\apk.ps1 -Release -IconSource assets/icon/icon.svg
```

The choice applies to that build only. To avoid specifying it each time, keep only your preferred source. In CI or PowerShell `-NonInteractive` mode, both files require an explicit choice. Invalid or missing sources produce a short error and a nonzero exit code; APK building stops. No silent fallback is used.

## SVG requirements

Use paths and a positive `viewBox="0 0 width height"`. Supported properties: fill/stroke (`#RGB`, `#RRGGBB`, `none`), stroke width, caps and joins. Flatten groups/transforms/styles and convert shapes/text into paths. Separate arc flags with spaces. Unsupported features stop generation with an error.

If using Gradle directly, first run `./update-icon.ps1` (or `./update-icon.ps1 -Source assets/icon/icon.png`). Direct Gradle builds do not regenerate icons automatically. Switching source types removes only the known generated icon files, including stale themed layers; it never deletes your source images. Install the newly built APK to see changes; launchers may cache icons.
