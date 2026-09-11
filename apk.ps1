param(
    [switch]$Debug,
    [switch]$Release,
    [switch]$Install
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Debug -and $Release) {
    throw 'Choose only one build type: -Debug or -Release.'
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
    throw "Gradle wrapper not found: $GradleWrapper"
}

$javaAvailable = $false
if ($env:JAVA_HOME) {
    $javaAvailable = Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\java.exe')
}
if (-not $javaAvailable) {
    $javaAvailable = $null -ne (Get-Command java.exe -ErrorAction SilentlyContinue)
}
if (-not $javaAvailable) {
    throw 'Java is not configured. Run .\setup.ps1, then retry.'
}

$SdkPath = Get-ProjectSdkPath
if (-not $SdkPath) {
    throw 'Android SDK is not configured. Run .\setup.ps1, then retry.'
}

if ($Release) {
    $signingStatus = Get-ReleaseSigningStatus
    if (-not $signingStatus.Ready) {
        Write-Host ''
        Write-Log 'Release signing is not configured.' 'ERROR'
        Write-Host $signingStatus.Reason -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Run:' -ForegroundColor DarkGray
        Write-Host '  .\setup-keys.ps1' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'Then:' -ForegroundColor DarkGray
        Write-Host '  .\apk.ps1 -Release' -ForegroundColor Green
        Write-Host '  .\apk.ps1 -Release -Install' -ForegroundColor Green
        Write-Host ''
        throw 'Release build stopped because signing is not configured.'
    }
}

Write-Log "Building $Variant APK..." 'BUILD'
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
    throw "Gradle $Variant build failed with exit code $gradleExitCode."
}

$apk = Get-BuiltApk
if (-not $apk) {
    throw "Build succeeded, but no APK was found under: $ApkRoot"
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
    throw 'Cannot install an unsigned APK. Configure release signing or use a Debug build.'
}

Write-Host ''
Write-Log 'Checking connected Android device...' 'CHECK'

$adb = Find-Adb -SdkPath $SdkPath
if (-not $adb) {
    throw 'ADB was not found. Run .\setup.ps1, then retry.'
}

$adbStart = Invoke-NativeCaptured -FilePath $adb -Arguments @('start-server')
if ($adbStart.ExitCode -ne 0) {
    $details = @($adbStart.StdOut, $adbStart.StdErr) | Where-Object { $_ } | ForEach-Object { $_.Trim() }
    throw "Failed to start the ADB server.`n$($details -join [Environment]::NewLine)"
}

$adbDevices = Invoke-NativeCaptured -FilePath $adb -Arguments @('devices')
if ($adbDevices.ExitCode -ne 0) {
    $details = @($adbDevices.StdOut, $adbDevices.StdErr) | Where-Object { $_ } | ForEach-Object { $_.Trim() }
    throw "Failed to query ADB devices.`n$($details -join [Environment]::NewLine)"
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
        throw "No authorized Android device is available: $($problemDevices -join ', '). Unlock the device and accept the USB debugging prompt."
    }
    throw 'No Android device is connected. Connect a device with USB debugging enabled, then retry with -Install.'
}

$serial = $null
if ($env:ANDROID_SERIAL -and $authorized -contains $env:ANDROID_SERIAL) {
    $serial = $env:ANDROID_SERIAL
}
elseif ($authorized.Count -eq 1) {
    $serial = $authorized[0]
}
else {
    throw "Multiple Android devices are connected: $($authorized -join ', '). Set ANDROID_SERIAL or leave only one device connected."
}

$modelResult = Invoke-NativeCaptured -FilePath $adb -Arguments @('-s', $serial, 'shell', 'getprop', 'ro.product.model')
$model = if ($modelResult.ExitCode -eq 0) { $modelResult.StdOut.Trim() } else { '' }
if (-not $model) {
    $model = $serial
}
Write-Log "$model [$serial]" 'DEVICE'

$androidCli = Find-AndroidCli
$installed = $false

if ($androidCli) {
    Write-Log "Installing $($apk.Name) with fast delta install..." 'INSTALL'

    $androidArgs = @(
        "--sdk=$SdkPath",
        'install',
        "--apks=$($apk.FullName)",
        "--device=$serial",
        '--use-delta-install'
    )

    $androidResult = Invoke-NativeCaptured -FilePath $androidCli -Arguments $androidArgs
    $androidOutput = @($androidResult.StdOut, $androidResult.StdErr) | Where-Object { $_ }
    if ($androidResult.ExitCode -eq 0) {
        $installed = $true
        Write-Log 'APK installed successfully using Android CLI delta install.' 'OK'
    }
    else {
        Write-Log 'Android CLI delta install failed; falling back to ADB.' 'WARN'
    }
}

if (-not $installed) {
    Write-Log "Installing $($apk.Name) with ADB..." 'INSTALL'
    $adbInstall = Invoke-NativeCaptured -FilePath $adb -Arguments @('-s', $serial, 'install', '-r', $apk.FullName)
    $adbOutput = @($adbInstall.StdOut, $adbInstall.StdErr) | Where-Object { $_ }
    if ($adbInstall.ExitCode -ne 0) {
        $details = if ($androidCli -and $androidOutput) {
            "Android CLI:`n$($androidOutput -join [Environment]::NewLine)`n`nADB:`n$($adbOutput -join [Environment]::NewLine)"
        }
        else {
            $adbOutput -join [Environment]::NewLine
        }
        throw "APK installation failed.`n$details"
    }

    Write-Log 'APK installed successfully using ADB.' 'OK'
}
