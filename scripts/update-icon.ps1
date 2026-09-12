[CmdletBinding()]
param(
    [string]$Source = '',
    [string]$Background = '#FFFFFF',
    [string]$Module = ''
)

Set-StrictMode -Version Latest
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ErrorActionPreference = 'Stop'
trap {
    Write-Host "[ERROR] $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}
. (Join-Path $ProjectRoot 'scripts\android-project.ps1')
$moduleInfo = Get-AndroidApplicationModule -ProjectRoot $ProjectRoot -Module $Module
$res = Join-Path $moduleInfo.Path 'src\main\res'
if (-not $Source) {
    $candidates = @('icon.svg', 'icon.png' | ForEach-Object { Join-Path $ProjectRoot "assets\icon\$_" } | Where-Object { Test-Path -LiteralPath $_ })
    if ($candidates.Count -eq 0) { throw 'Add assets/icon/icon.svg or a 1024x1024 icon.png. See README.md.' }
    if ($candidates.Count -gt 1) {
        if ($env:CI -or [Environment]::GetCommandLineArgs() -match '^-NonInteractive$') {
            throw 'Both icons exist. Specify -Source assets/icon/icon.png (update-icon.ps1) or -IconSource assets/icon/icon.png (apk.ps1).'
        }
        Write-Host 'Both icon files are available. Choose one for this build:'
        Write-Host '  1. SVG (icon.svg)'
        Write-Host '  2. PNG (icon.png)'
        Write-Host '  Q. Cancel'
        do {
            $choice = (Read-Host 'Choose 1 or 2').Trim().ToLowerInvariant()
            if ($choice -in @('', 'q')) { Write-Host '[CANCELLED] No icon files changed.'; exit 1 }
            if ($choice -notin @('1', '2', 'svg', 'png')) { Write-Host 'Please enter 1 for SVG, 2 for PNG, or Q to cancel.' -ForegroundColor Yellow }
        } while ($choice -notin @('1', '2', 'svg', 'png'))
        $name = if ($choice -in @('1', 'svg')) { 'icon.svg' } else { 'icon.png' }
        $Source = Join-Path $ProjectRoot "assets\icon\$name"
    } else { $Source = $candidates[0] }
} elseif (-not [IO.Path]::IsPathRooted($Source)) {
    $Source = Join-Path $ProjectRoot $Source
}
if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw "Icon file not found: $Source" }
if ([IO.Path]::GetExtension($Source) -ieq '.png') {
    & (Join-Path $ProjectRoot 'scripts\png-icon.ps1') -Source $Source -ResPath $res -Background $Background
    exit 0
}
if ([IO.Path]::GetExtension($Source) -ine '.svg') { throw 'Only .svg and .png icons are supported. See README.md.' }
$culture = [Globalization.CultureInfo]::InvariantCulture

function Color([string]$value) {
    if ($value -eq 'none') { return '#00000000' }
    if ($value -match '^#[0-9a-fA-F]{3}$') {
        return '#' + $value[1] + $value[1] + $value[2] + $value[2] + $value[3] + $value[3]
    }
    if ($value -match '^#[0-9a-fA-F]{6}$') { return $value }
    throw "Use SVG colors as #RGB, #RRGGBB or none; received '$value'."
}
function Escape([string]$value) { return [Security.SecurityElement]::Escape($value) }

# Reject unsupported SVG features instead of silently producing a different icon.
$settings = [Xml.XmlReaderSettings]::new()
$settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
$settings.XmlResolver = $null
$reader = [Xml.XmlReader]::Create((Resolve-Path -LiteralPath $Source).Path, $settings)
try {
    $svg = [Xml.XmlDocument]::new()
    $svg.Load($reader)
} finally { $reader.Dispose() }
$root = $svg.DocumentElement
if ($root.LocalName -ne 'svg') { throw 'The source must be an SVG.' }
$viewBox = $root.GetAttribute('viewBox').Trim() -split '[,\s]+'
if ($viewBox.Count -ne 4) { throw 'Provide viewBox="0 0 width height".' }
$numbers = @($viewBox | ForEach-Object { [double]::Parse($_, $culture) })
if ($numbers[0] -ne 0 -or $numbers[1] -ne 0 -or $numbers[2] -le 0 -or $numbers[3] -le 0) {
    throw 'Use a positive viewBox starting at 0 0.'
}
$allowed = @('xmlns','viewBox','width','height','fill','stroke','stroke-width','stroke-linecap','stroke-linejoin','d')
foreach ($element in $svg.SelectNodes('//*')) {
    if ($element.LocalName -notin @('svg','path')) { throw 'Only path-based SVGs are supported. Convert shapes/text to paths and flatten groups first.' }
    foreach ($attribute in $element.Attributes) {
        if ($attribute.Name -notin $allowed) { throw "Unsupported SVG attribute '$($attribute.Name)'. Flatten styles and transforms first." }
    }
}
$paths = @($root.SelectNodes('*'))
if ($paths.Count -eq 0) { throw 'The SVG needs at least one path.' }
$body = ''
foreach ($path in $paths) {
    $values = @{}
    foreach ($pair in @(@('fill','#000000'),@('stroke','none'),@('stroke-width','1'),@('stroke-linecap','butt'),@('stroke-linejoin','miter'))) {
        $name = $pair[0]
        $values[$name] = if ($path.HasAttribute($name)) { $path.GetAttribute($name) } elseif ($root.HasAttribute($name)) { $root.GetAttribute($name) } else { $pair[1] }
    }
    if (-not $path.GetAttribute('d')) { throw 'Each path needs path data (d).' }
    $body += '<path android:pathData="' + (Escape $path.GetAttribute('d')) + '" android:fillColor="' + (Color $values['fill']) + '" android:strokeColor="' + (Color $values['stroke']) + '" android:strokeWidth="' + (Escape $values['stroke-width']) + '" android:strokeLineCap="' + (Escape $values['stroke-linecap']) + '" android:strokeLineJoin="' + (Escape $values['stroke-linejoin']) + '" />' + "`n"
}
$scale = 44.0 / [Math]::Max($numbers[2], $numbers[3])
$x = (108 - $numbers[2] * $scale) / 2
$y = (108 - $numbers[3] * $scale) / 2
$group = '<group android:scaleX="' + $scale.ToString('G15', $culture) + '" android:scaleY="' + $scale.ToString('G15', $culture) + '" android:translateX="' + $x.ToString('G15', $culture) + '" android:translateY="' + $y.ToString('G15', $culture) + '">' + "`n" + $body + '</group>'
$header = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">'
$backgroundPath = '<path android:fillColor="' + (Color $Background) + '" android:pathData="M0,0h108v108h-108z" />'
$files = @{
    'drawable\ic_launcher_foreground.xml' = $header + $group + '</vector>'
    'drawable\ic_launcher_background.xml' = $header + $backgroundPath + '</vector>'
    'mipmap-anydpi\ic_launcher.xml' = $header + $backgroundPath + $group + '</vector>'
    'mipmap-anydpi-v26\ic_launcher.xml' = '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/ic_launcher_background"/><foreground android:drawable="@drawable/ic_launcher_foreground"/></adaptive-icon>'
    'mipmap-anydpi-v33\ic_launcher.xml' = '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/ic_launcher_background"/><foreground android:drawable="@drawable/ic_launcher_foreground"/><monochrome android:drawable="@drawable/ic_launcher_foreground"/></adaptive-icon>'
}
foreach ($entry in $files.GetEnumerator()) {
    $destination = Join-Path $res $entry.Key
    New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
    [IO.File]::WriteAllText($destination, $entry.Value + "`n", [Text.UTF8Encoding]::new($false))
}
# Remove only generated PNG resources when switching back to SVG.
foreach ($relative in @('drawable-nodpi\ic_launcher_image.png','mipmap-mdpi\ic_launcher.png','mipmap-hdpi\ic_launcher.png','mipmap-xhdpi\ic_launcher.png','mipmap-xxhdpi\ic_launcher.png','mipmap-xxxhdpi\ic_launcher.png')) {
    $old = Join-Path $res $relative
    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
}
Write-Host '[OK] Launcher icons updated from SVG.'
exit 0
