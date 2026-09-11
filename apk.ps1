[CmdletBinding()]
param([switch]$Release,[switch]$Install,[switch]$SkipSetup)
$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
 if (-not $SkipSetup) { & "$PSScriptRoot/setup-environment.ps1"; if (-not $?) { throw 'Setup failed.' } }
 $variant = if ($Release) { 'Release' } else { 'Debug' }
 & "$PSScriptRoot/gradlew.bat" ":app:lint$variant" ":app:assemble$variant"
 if ($LASTEXITCODE) { throw 'Build failed; do not use a stale APK.' }
 $apk = Join-Path $PSScriptRoot "app/build/outputs/apk/$($variant.ToLower())/app-$($variant.ToLower()).apk"
 if (-not (Test-Path $apk)) { throw "Expected APK missing: $apk" }
 Write-Host "APK ready: $apk"
 if ($Install) {
  & "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r $apk
  if ($LASTEXITCODE) { throw 'Installation failed. Check device authorization and signing identity.' }
 }
} finally { Pop-Location }
