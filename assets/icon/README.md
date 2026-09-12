# Icon source

Keep `icon.svg` **or** `icon.png` here. PNG must be a still, square **1024 x 1024** image; color and transparency are supported.

If both files exist, the script asks you to choose SVG or PNG. Enter 1 for SVG, 2 for PNG, or Q to cancel. Skip the prompt with `./scripts/apk.ps1 -Release -Icon png` or `-Icon svg`. Use `-IconSource` instead for custom paths; do not combine it with `-Icon`.

See [the app README](../../README.md) for build instructions.
