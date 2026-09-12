param(
    [switch]$Debug,
    [switch]$Release,
    [switch]$Install,
    [string]$IconSource = '',
    [Alias('Image')]
    [string]$Icon = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Validate manually so invalid choices produce a concise error, not a binding dump.
if ($PSBoundParameters.ContainsKey('Icon')) {
    $Icon = $Icon.Trim().ToLowerInvariant()
    if ($Icon -notin @('png', 'svg')) {
        Write-Host '[ERROR] -Icon must be png or svg. Example: .\apk.ps1 -Release -Icon png' -ForegroundColor Red
        exit 1
    }
    if ($PSBoundParameters.ContainsKey('IconSource')) {
        Write-Host '[ERROR] Use either -Icon or -IconSource, not both.' -ForegroundColor Red
        exit 1
    }
    $IconSource = "assets/icon/icon.$Icon"
}
if ($PSBoundParameters.ContainsKey('IconSource') -and [string]::IsNullOrWhiteSpace($IconSource)) {
    Write-Host '[ERROR] -IconSource needs a file path. Example: -IconSource assets/icon/icon.png' -ForegroundColor Red
    exit 1
}
if ($IconSource) {
    $iconPath = if ([IO.Path]::IsPathRooted($IconSource)) { $IconSource } else { Join-Path $PSScriptRoot $IconSource }
    if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
        Write-Host "[ERROR] Icon file not found: $iconPath" -ForegroundColor Red
        exit 1
    }
    if ([IO.Path]::GetExtension($iconPath) -notin @('.png', '.svg')) {
        Write-Host '[ERROR] Icon source must be a .png or .svg file.' -ForegroundColor Red
        exit 1
    }
}

if ($Debug -and $Release) {
    Write-Host '[ERROR] Choose only one build type: -Debug or -Release.' -ForegroundColor Red
    exit 1
}

$Variant = if ($Release) { 'Release' } else { 'Debug' }
$VariantLower = $Variant.ToLowerInvariant()
$GradleWrapper = Join-Path $PSScriptRoot 'gradlew.bat'
$ApkRoot = Join-Path $PSScriptRoot 'app\build\outputs\apk'
$ExpectedApk = Join-Path $ApkRoot "$VariantLower\app-$VariantLower.apk"

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('BUILD', 'CHECK', 'DEVICE', 'INSTALL', 'OK', 'INFO', 'WARN', 'ERROR')]
        [string]$Type = 'INFO'
    )

    $typeColor = switch ($Type) {
        'BUILD'   { 'Cyan' }
        'CHECK'   { 'DarkCyan' }
        'DEVICE'  { 'Magenta' }
        'INSTALL' { 'Yellow' }
        'OK'      { 'Green' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        default   { 'Gray' }
    }

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -ForegroundColor DarkGray -NoNewline
    Write-Host "[$Type] " -ForegroundColor $typeColor -NoNewline
    Write-Host $Message
}

function Write-KeyValue {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value,
        [ConsoleColor]$ValueColor = [ConsoleColor]::White
    )

    Write-Host "${Key}: " -ForegroundColor DarkGray -NoNewline
    Write-Host $Value -ForegroundColor $ValueColor
}

function Stop-Script {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Details
    )

    Write-Host ''
    Write-Log $Message 'ERROR'
    if ($Details) {
        Write-Host $Details -ForegroundColor DarkGray
    }
    exit 1
}

function Stop-InstallFailure {
    param([Parameter(Mandatory)][string]$Output)

    if ($Output -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match') {
        Stop-Script 'Installed app uses a different signing key.' @"
The existing wifi.login.auto app was signed with another key.
Uninstall the old app, then run this command again:

  adb uninstall wifi.login.auto
  .\apk.ps1 -Release -Install

Warning: uninstalling removes that app's saved data.
"@
    }

    if ($Output -match 'INSTALL_FAILED_VERSION_DOWNGRADE') {
        Stop-Script 'The installed app has a higher versionCode.' @"
Increase versionCode for the new build, or uninstall the installed app before retrying.
Uninstalling removes that app's saved data.
"@
    }

    if ($Output -match 'INSTALL_FAILED_INSUFFICIENT_STORAGE') {
        Stop-Script 'The phone does not have enough free storage.' 'Free some storage on the phone, then retry.'
    }

    if ($Output -match 'INSTALL_FAILED_USER_RESTRICTED') {
        Stop-Script 'Android blocked the installation.' 'Unlock the phone and check its USB/install security settings, then retry.'
    }

    if ($Output -match 'INSTALL_FAILED_OLDER_SDK') {
        Stop-Script 'This Android version is too old for the APK.' 'Use a supported Android device.'
    }

    Stop-Script 'APK installation failed.' $Output.Trim()
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Argument)

    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
        return $Argument
    }

    # Windows CommandLineToArgvW quoting rules: double backslashes that precede a
    # quote, escape embedded quotes, and double trailing backslashes before the
    # closing quote.
    $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-NativeCaptured {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        $null = $process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()

        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut   = $stdoutTask.GetAwaiter().GetResult()
            StdErr   = $stderrTask.GetAwaiter().GetResult()
        }
    }
    finally {
        $process.Dispose()
    }
}

function Get-ProjectSdkPath {
    $candidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User'),
        [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'Machine')
    ) | Where-Object { $_ }

    $localProperties = Join-Path $PSScriptRoot 'local.properties'
    if (Test-Path -LiteralPath $localProperties) {
        $sdkLine = Get-Content -LiteralPath $localProperties -ErrorAction SilentlyContinue |
            Where-Object { $_ -match '^\s*sdk\.dir\s*=' } |
            Select-Object -First 1

        if ($sdkLine -and $sdkLine -match '^\s*sdk\.dir\s*=\s*(.+?)\s*$') {
            $localSdk = $Matches[1]
            $localSdk = $localSdk -replace '\\:', ':'
            $localSdk = $localSdk -replace '\\\\', '\'
            $candidates = @($localSdk) + $candidates
        }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Find-Adb {
    param([string]$SdkPath)

    if ($SdkPath) {
        $candidate = Join-Path $SdkPath 'platform-tools\adb.exe'
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $command = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

function Find-AndroidCli {
    $command = Get-Command android.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

function Get-ReleaseSigningStatus {
    $propertiesPath = Join-Path $PSScriptRoot 'keystore.properties'

    if (-not (Test-Path -LiteralPath $propertiesPath)) {
        return [pscustomobject]@{
            Ready  = $false
            Reason = 'keystore.properties is missing.'
        }
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $propertiesPath -ErrorAction Stop) {
        if ($line -match '^\s*[#!]') {
            continue
        }

        if ($line -match '^\s*(storeFile|storePassword|keyAlias|keyPassword)\s*[:=]\s*(.*)$') {
            $values[$Matches[1]] = $Matches[2]
        }
    }

    foreach ($required in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
        if (-not $values.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($values[$required])) {
            return [pscustomobject]@{
                Ready  = $false
                Reason = "keystore.properties is missing a value for '$required'."
            }
        }
    }

    $storeFile = $values['storeFile'].Trim()
    $storeFile = $storeFile -replace '\\:', ':'
    $storeFile = $storeFile -replace '\\ ', ' '
    $storeFile = $storeFile -replace '\\\\', '\'

    $keystorePath = if ([IO.Path]::IsPathRooted($storeFile)) {
        $storeFile
    }
    else {
        Join-Path $PSScriptRoot $storeFile
    }

    if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) {
        return [pscustomobject]@{
            Ready  = $false
            Reason = "Signing keystore was not found: $keystorePath"
        }
    }

    return [pscustomobject]@{
        Ready        = $true
        Reason       = $null
        KeystorePath = $keystorePath
        Alias        = $values['keyAlias']
    }
}

function Get-BuiltApk {
    if (Test-Path -LiteralPath $ExpectedApk) {
        return Get-Item -LiteralPath $ExpectedApk
    }

    if (-not (Test-Path -LiteralPath $ApkRoot)) {
        return $null
    }

    $allApks = @(Get-ChildItem -LiteralPath $ApkRoot -Filter '*.apk' -File -Recurse -ErrorAction SilentlyContinue)
    if ($allApks.Count -eq 0) {
        return $null
    }

    $variantApks = @($allApks | Where-Object {
        $_.FullName -match "[\\/]$([regex]::Escape($VariantLower))[\\/]" -or
        $_.Name -match "(?i)$([regex]::Escape($VariantLower))"
    })

    $candidates = if ($variantApks.Count -gt 0) { $variantApks } else { $allApks }
    return $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $GradleWrapper)) {
    Stop-Script 'Gradle wrapper is missing.' $GradleWrapper
}

$javaAvailable = $false
if ($env:JAVA_HOME) {
    $javaAvailable = Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\java.exe')
}
if (-not $javaAvailable) {
    $javaAvailable = $null -ne (Get-Command java.exe -ErrorAction SilentlyContinue)
}
if (-not $javaAvailable) {
    Stop-Script 'Java is not configured.' 'Run .\setup.ps1, then retry.'
}

$SdkPath = Get-ProjectSdkPath
if (-not $SdkPath) {
    Stop-Script 'Android SDK is not configured.' 'Run .\setup.ps1, then retry.'
}

if ($Release) {
    $signingStatus = Get-ReleaseSigningStatus
    if (-not $signingStatus.Ready) {
        Stop-Script 'Release signing is not configured.' "$($signingStatus.Reason)`nRun .\setup-keys.ps1, then retry .\apk.ps1 -Release."
    }
}

Write-Log "Building $Variant APK..." 'BUILD'
& (Join-Path $PSScriptRoot 'update-icon.ps1') -Source $IconSource
if ($LASTEXITCODE -ne 0) { exit 1 }
$timer = [Diagnostics.Stopwatch]::StartNew()

Push-Location -LiteralPath $PSScriptRoot
try {
    & $GradleWrapper ":app:assemble$Variant"
    $gradleExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
    $timer.Stop()
}

if ($gradleExitCode -ne 0) {
    Stop-Script "Gradle $Variant build failed." "Exit code: $gradleExitCode"
}

$apk = Get-BuiltApk
if (-not $apk) {
    Stop-Script 'Build finished, but no APK was found.' $ApkRoot
}

$sizeKb = $apk.Length / 1KB
if ($sizeKb -gt 1024) {
    $displaySize = "$([math]::Round($apk.Length / 1MB, 2)) MB"
}
else {
    $displaySize = "$([math]::Round($sizeKb, 2)) KB"
}

Write-Host ''
Write-Log "$Variant APK ready in $($timer.Elapsed.TotalSeconds.ToString('0.0'))s" 'OK'
Write-KeyValue 'Path' $apk.DirectoryName Cyan
Write-KeyValue 'Size' $displaySize Green

$isUnsigned = $apk.Name -match '(?i)unsigned'
if ($isUnsigned) {
    Write-Log 'The generated release APK is unsigned. Configure release signing before distributing or installing it.' 'WARN'
}

if (-not $Install) {
    return
}

if ($isUnsigned) {
    Stop-Script 'Cannot install an unsigned APK.' 'Configure release signing or use a Debug build.'
}

Write-Host ''
Write-Log 'Checking connected Android device...' 'CHECK'

$adb = Find-Adb -SdkPath $SdkPath
if (-not $adb) {
    Stop-Script 'ADB was not found.' 'Run .\setup.ps1, then retry.'
}

$adbStart = Invoke-NativeCaptured -FilePath $adb -Arguments @('start-server')
if ($adbStart.ExitCode -ne 0) {
    $details = @($adbStart.StdOut, $adbStart.StdErr) | Where-Object { $_ } | ForEach-Object { $_.Trim() }
    Stop-Script 'Failed to start the ADB server.' ($details -join [Environment]::NewLine)
}

$adbDevices = Invoke-NativeCaptured -FilePath $adb -Arguments @('devices')
if ($adbDevices.ExitCode -ne 0) {
    $details = @($adbDevices.StdOut, $adbDevices.StdErr) | Where-Object { $_ } | ForEach-Object { $_.Trim() }
    Stop-Script 'Failed to query ADB devices.' ($details -join [Environment]::NewLine)
}
$deviceOutput = @($adbDevices.StdOut -split "`r?`n")

$authorized = @()
$problemDevices = @()

foreach ($line in $deviceOutput) {
    if ($line -match '^([^\s]+)\s+device(?:\s|$)') {
        $authorized += $Matches[1]
    }
    elseif ($line -match '^([^\s]+)\s+(unauthorized|offline)(?:\s|$)') {
        $problemDevices += "$($Matches[1]) ($($Matches[2]))"
    }
}

if ($authorized.Count -eq 0) {
    if ($problemDevices.Count -gt 0) {
        Stop-Script 'No authorized Android device is available.' "$($problemDevices -join ', '). Unlock the device and accept the USB debugging prompt."
    }
    Stop-Script 'No Android device is connected.' 'Connect a device with USB debugging enabled, then retry with -Install.'
}

$serial = $null
if ($env:ANDROID_SERIAL -and $authorized -contains $env:ANDROID_SERIAL) {
    $serial = $env:ANDROID_SERIAL
}
elseif ($authorized.Count -eq 1) {
    $serial = $authorized[0]
}
else {
    Stop-Script 'Multiple Android devices are connected.' "$($authorized -join ', '). Set ANDROID_SERIAL or leave only one device connected."
}

$modelResult = Invoke-NativeCaptured -FilePath $adb -Arguments @('-s', $serial, 'shell', 'getprop', 'ro.product.model')
$model = if ($modelResult.ExitCode -eq 0) { $modelResult.StdOut.Trim() } else { '' }
if (-not $model) {
    $model = $serial
}
Write-Log "$model [$serial]" 'DEVICE'

Write-Log "Installing $($apk.Name) with ADB..." 'INSTALL'

$adbInstall = Invoke-NativeCaptured -FilePath $adb -Arguments @(
    '-s', $serial,
    'install',
    '-r',
    $apk.FullName
)

$adbOutput = @($adbInstall.StdOut, $adbInstall.StdErr) | Where-Object { $_ }

if ($adbInstall.ExitCode -ne 0) {
    $details = $adbOutput -join [Environment]::NewLine
    Stop-InstallFailure -Output $details
}

Write-Log 'APK installed successfully using ADB.' 'OK'
