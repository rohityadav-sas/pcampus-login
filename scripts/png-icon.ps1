[CmdletBinding()]
param([Parameter(Mandatory)][string]$Source, [string]$Background = '#FFFFFF')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if ($Background -notmatch '^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$') { throw 'PNG background must be an opaque #RGB or #RRGGBB color.' }
$backgroundColor = [Drawing.ColorTranslator]::FromHtml($Background)
$bytes = [IO.File]::ReadAllBytes($Source)
if ($bytes.Length -lt 8 -or [BitConverter]::ToString($bytes,0,8) -ne '89-50-4E-47-0D-0A-1A-0A') { throw 'The file is not a real PNG. Export it as PNG; renaming another format is not enough.' }
try { $inputImage = [Drawing.Image]::FromFile($Source) } catch { throw 'Cannot decode this PNG. Re-export a standard, non-animated 1024x1024 PNG.' }
try {
    if ($inputImage.Width -ne 1024 -or $inputImage.Height -ne 1024) {
        throw "PNG must be exactly 1024x1024 pixels; received $($inputImage.Width)x$($inputImage.Height). Export a square 1024x1024 image. See docs/ICONS.md."
    }
    # APNG is not supported. Parse chunk headers, not arbitrary pixel bytes.
    $offset = 8
    while ($offset + 12 -le $bytes.Length) {
        $length = [uint32]$bytes[$offset] * 16777216L + [uint32]$bytes[$offset+1] * 65536L + [uint32]$bytes[$offset+2] * 256L + [uint32]$bytes[$offset+3]
        $kind = [Text.Encoding]::ASCII.GetString($bytes,$offset+4,4)
        if ($kind -eq 'acTL') { throw 'Animated PNG is unsupported. Export a single still 1024x1024 PNG.' }
        $offset += 12 + $length
        if ($kind -eq 'IEND') { break }
    }
    $res = Join-Path (Split-Path $PSScriptRoot -Parent) 'app\src\main\res'
    function Save-Icon([string]$relative, [int]$size, [bool]$opaque) {
        $destination = Join-Path $res $relative
        New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
        $bitmap = [Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            if ($opaque) { $graphics.Clear($backgroundColor) } else { $graphics.Clear([Drawing.Color]::Transparent) }
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            # Keep the full artwork inside the adaptive icon's safe circle.
            $side = [int][Math]::Round($size * 44.0 / 108.0)
            $position = [int][Math]::Floor(($size-$side)/2)
            $graphics.DrawImage($inputImage,$position,$position,$side,$side)
            $bitmap.Save($destination,[Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
    Save-Icon 'drawable-nodpi\ic_launcher_image.png' 432 $false
    foreach ($density in @(@('mdpi',48),@('hdpi',72),@('xhdpi',96),@('xxhdpi',144),@('xxxhdpi',192))) {
        Save-Icon "mipmap-$($density[0])\ic_launcher.png" $density[1] $true
    }
    $files = @{
        'drawable\ic_launcher_foreground.xml' = '<bitmap xmlns:android="http://schemas.android.com/apk/res/android" android:src="@drawable/ic_launcher_image" android:gravity="fill" android:filter="true" />'
        'drawable\ic_launcher_background.xml' = '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="' + $Background + '" /></shape>'
        'mipmap-anydpi-v26\ic_launcher.xml' = '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/ic_launcher_background"/><foreground android:drawable="@drawable/ic_launcher_foreground"/></adaptive-icon>'
    }
    foreach ($entry in $files.GetEnumerator()) {
        $destination = Join-Path $res $entry.Key
        New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
        [IO.File]::WriteAllText($destination,$entry.Value + "`n",[Text.UTF8Encoding]::new($false))
    }
    # PNG remains full-color. Do not reuse the previous SVG's themed silhouette.
    foreach ($relative in @('mipmap-anydpi\ic_launcher.xml','mipmap-anydpi-v33\ic_launcher.xml')) {
        $old = Join-Path $res $relative
        if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
    }
    Write-Host '[OK] Full-color PNG launcher icons generated. No custom monochrome layer.'
} finally { $inputImage.Dispose() }
