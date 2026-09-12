[CmdletBinding()]
param(
    [int]$MinimumJavaVersion = 17,
    [int]$MaximumJavaVersion = 24,
    [int]$CompileSdk = 0,
    [string]$BuildToolsVersion = '',
    [string]$Module = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http

$DefaultAndroidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$JavaRoot = Join-Path $env:LOCALAPPDATA 'Programs\Java'
$OracleJdkUrl = 'https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.zip'
$AndroidCliInstallerUrl = 'https://dl.google.com/android/cli/latest/windows_x86_64/install.cmd'

. (Join-Path $PSScriptRoot 'scripts\android-project.ps1')
$moduleInfo = Get-AndroidApplicationModule -ProjectRoot $PSScriptRoot -Module $Module
$projectRequirements = Get-AndroidProjectRequirements -ModuleInfo $moduleInfo
if ($CompileSdk -le 0) { $CompileSdk = $projectRequirements.CompileSdk }
if (-not $BuildToolsVersion -and $projectRequirements.BuildToolsVersion) {
    $BuildToolsVersion = $projectRequirements.BuildToolsVersion
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('CHECK', 'INFO', 'DOWNLOAD', 'INSTALL', 'CONFIG', 'OK', 'WARN')]
        [string]$Type = 'INFO'
    )

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [$Type] $Message"
}

function Normalize-PathEntry {
    param([string]$Path)

    if (-not $Path) {
        return $null
    }

    return $Path.Trim().TrimEnd('\', '/')
}

function Set-UserEnvironmentVariableIfNeeded {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )

    $current = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ((Normalize-PathEntry $current) -ine (Normalize-PathEntry $Value)) {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        Write-Log "$Name=$Value" 'CONFIG'
    }
}

function Add-ToUserPath {
    param([Parameter(Mandatory)][string[]]$Paths)

    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($current -split ';' | Where-Object { $_ })
    $changed = $false

    foreach ($requiredPath in $Paths) {
        if (-not $requiredPath) {
            continue
        }

        $normalizedRequired = Normalize-PathEntry $requiredPath
        $exists = $false

        foreach ($entry in $entries) {
            if ((Normalize-PathEntry $entry) -ieq $normalizedRequired) {
                $exists = $true
                break
            }
        }

        if (-not $exists) {
            $entries += $requiredPath
            $changed = $true
            Write-Log "Added to user Path: $requiredPath" 'CONFIG'
        }
    }

    if ($changed) {
        [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
    }
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = @($machinePath, $userPath) -join ';'
}

function Invoke-Download {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Name
    )

    Write-Log "Downloading $Name..." 'DOWNLOAD'

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromMinutes(30)
    $response = $null
    $inputStream = $null
    $outputStream = $null
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()

    try {
        $response = $client.GetAsync($Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $null = $response.EnsureSuccessStatusCode()

        $totalBytes = $response.Content.Headers.ContentLength
        $inputStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $outputStream = [IO.File]::Open($Destination, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)

        $buffer = New-Object byte[] 1048576
        [long]$downloaded = 0
        $lastProgressUpdate = [DateTime]::MinValue

        while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $outputStream.Write($buffer, 0, $read)
            $downloaded += $read

            if (((Get-Date) - $lastProgressUpdate).TotalMilliseconds -ge 250) {
                $mb = $downloaded / 1MB
                $speed = if ($stopwatch.Elapsed.TotalSeconds -gt 0) { $mb / $stopwatch.Elapsed.TotalSeconds } else { 0 }

                if ($totalBytes -and $totalBytes -gt 0) {
                    $percent = [math]::Min(100, [math]::Floor(($downloaded / $totalBytes) * 100))
                    $totalMb = $totalBytes / 1MB
                    Write-Progress -Activity "Downloading $Name" -Status ("{0:N1}/{1:N1} MB - {2:N1} MB/s" -f $mb, $totalMb, $speed) -PercentComplete $percent
                }
                else {
                    Write-Progress -Activity "Downloading $Name" -Status ("{0:N1} MB - {1:N1} MB/s" -f $mb, $speed)
                }

                $lastProgressUpdate = Get-Date
            }
        }
    }
    catch {
        if (Test-Path -LiteralPath $Destination) {
            Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    finally {
        Write-Progress -Activity "Downloading $Name" -Completed
        $stopwatch.Stop()
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
        $client.Dispose()
    }

    Write-Log "$Name download complete." 'OK'
}

function Get-JavaMajorVersion {
    param([Parameter(Mandatory)][string]$JavaHome)

    $javaExe = Join-Path $JavaHome 'bin\java.exe'
    $javacExe = Join-Path $JavaHome 'bin\javac.exe'

    if (-not (Test-Path -LiteralPath $javaExe) -or -not (Test-Path -LiteralPath $javacExe)) {
        return $null
    }

    # java -version writes its normal version text to STDERR. In Windows PowerShell 5.1,
    # merging that stream with 2>&1 while $ErrorActionPreference='Stop' can incorrectly
    # promote the normal output to a terminating NativeCommandError. Capture it directly.
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $javaExe
    $startInfo.Arguments = '-version'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            return $null
        }

        $versionOutput = if ($stderr) { $stderr } else { $stdout }
        $versionOutput = (($versionOutput -split "`r?`n") | Select-Object -First 1).Trim()
    }
    finally {
        $process.Dispose()
    }

    if ($versionOutput -notmatch '"(?<major>\d+)(?:\.(?<minor>\d+))?') {
        return $null
    }

    $major = [int]$Matches['major']
    if ($major -eq 1 -and $Matches['minor']) {
        $major = [int]$Matches['minor']
    }

    return $major
}

function Find-CompatibleJdk {
    $candidates = @(
        $env:JAVA_HOME,
        [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User'),
        [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    ) | Where-Object { $_ }

    foreach ($javaCommand in @(Get-Command java.exe -All -ErrorAction SilentlyContinue)) {
        $candidates += Split-Path (Split-Path $javaCommand.Source -Parent) -Parent
    }

    $searchRoots = @(
        $JavaRoot,
        (Join-Path $env:ProgramFiles 'Java'),
        (Join-Path $env:ProgramFiles 'Microsoft'),
        (Join-Path $env:ProgramFiles 'Eclipse Adoptium')
    )

    foreach ($root in $searchRoots) {
        if (Test-Path -LiteralPath $root) {
            $candidates += @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
        }
    }

    foreach ($candidate in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        $major = Get-JavaMajorVersion -JavaHome $candidate
        if ($null -ne $major -and $major -ge $MinimumJavaVersion -and $major -le $MaximumJavaVersion) {
            return [pscustomobject]@{
                Home = $candidate
                Major = $major
            }
        }
    }

    return $null
}

function Get-LocalPropertiesSdkPath {
    $localProperties = Join-Path $PSScriptRoot 'local.properties'
    if (-not (Test-Path -LiteralPath $localProperties)) {
        return $null
    }

    $sdkLine = Get-Content -LiteralPath $localProperties -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^\s*sdk\.dir\s*=' } |
        Select-Object -First 1

    if (-not $sdkLine -or $sdkLine -notmatch '^\s*sdk\.dir\s*=\s*(.+?)\s*$') {
        return $null
    }

    $path = $Matches[1]
    $path = $path -replace '\\:', ':'
    $path = $path -replace '\\\\', '\'
    return $path
}

function Find-AndroidSdk {
    $candidates = @(
        $env:ANDROID_HOME,
        [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User'),
        [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'Machine'),
        (Get-LocalPropertiesSdkPath),
        $env:ANDROID_SDK_ROOT,
        [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User'),
        [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'Machine'),
        $DefaultAndroidSdk
    ) | Where-Object { $_ }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $DefaultAndroidSdk
}

function Find-AndroidCli {
    Refresh-ProcessPath

    $command = Get-Command android.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    foreach ($entry in @($userPath -split ';' | Where-Object { $_ })) {
        $candidate = Join-Path $entry 'android.exe'
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Install-AndroidCli {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("android-cli-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    try {
        $installer = Join-Path $tempRoot 'install.cmd'
        Invoke-Download -Uri $AndroidCliInstallerUrl -Destination $installer -Name 'Android CLI installer'

        Write-Log 'Installing Android CLI for the current user...' 'INSTALL'

        # Capture stdout so installer chatter does not become part of this
        # function's return value. Keep successful setup concise; print the
        # captured output only when installation fails.
        $installerOutput = & $env:ComSpec /d /c "`"$installer`""
        $installerExitCode = $LASTEXITCODE

        if ($installerExitCode -ne 0) {
            foreach ($line in @($installerOutput)) {
                if ($null -ne $line -and "$line".Length -gt 0) {
                    Write-Host $line
                }
            }
            throw "Android CLI installer failed with exit code $installerExitCode."
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $cli = Find-AndroidCli
    if (-not $cli) {
        throw 'Android CLI installation completed, but android.exe was not found on PATH.'
    }

    Add-ToUserPath @((Split-Path $cli -Parent))
    Refresh-ProcessPath
    return $cli
}

Write-Log "Checking for a complete JDK $MinimumJavaVersion through $MaximumJavaVersion..." 'CHECK'
$jdk = Find-CompatibleJdk

if (-not $jdk) {
    Write-Log 'No compatible JDK was found; installing Oracle JDK 21.' 'INFO'
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("jdk21-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    try {
        $archive = Join-Path $tempRoot 'jdk.zip'
        $checksumFile = Join-Path $tempRoot 'jdk.sha256'

        Invoke-Download -Uri $OracleJdkUrl -Destination $archive -Name 'Oracle JDK 21'
        Invoke-Download -Uri ($OracleJdkUrl + '.sha256') -Destination $checksumFile -Name 'Oracle JDK checksum'

        Write-Log 'Verifying JDK checksum...' 'CHECK'
        $expectedHash = ((Get-Content -LiteralPath $checksumFile -Raw).Trim() -split '\s+')[0]
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash

        if ($expectedHash -notmatch '^[a-fA-F0-9]{64}$' -or $actualHash -ine $expectedHash) {
            throw 'Oracle JDK checksum verification failed.'
        }
        Write-Log 'JDK checksum verified.' 'OK'

        New-Item -ItemType Directory -Path $JavaRoot -Force | Out-Null
        Write-Log "Extracting Oracle JDK 21 to $JavaRoot..." 'INSTALL'
        Expand-Archive -LiteralPath $archive -DestinationPath $JavaRoot -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $jdk = Find-CompatibleJdk
    if (-not $jdk) {
        throw 'Oracle JDK was extracted, but a compatible JDK could not be found.'
    }

    Write-Log "Oracle JDK $($jdk.Major) installed at $($jdk.Home)" 'OK'
}
else {
    Write-Log "Compatible JDK $($jdk.Major) found at $($jdk.Home)" 'OK'
}

$JavaHome = $jdk.Home
$env:JAVA_HOME = $JavaHome
Set-UserEnvironmentVariableIfNeeded -Name 'JAVA_HOME' -Value $JavaHome
Add-ToUserPath @((Join-Path $JavaHome 'bin'))

$AndroidSdk = Find-AndroidSdk
if (-not (Test-Path -LiteralPath $AndroidSdk)) {
    New-Item -ItemType Directory -Path $AndroidSdk -Force | Out-Null
    Write-Log "Created Android SDK directory: $AndroidSdk" 'CONFIG'
}

$env:ANDROID_HOME = $AndroidSdk
Set-UserEnvironmentVariableIfNeeded -Name 'ANDROID_HOME' -Value $AndroidSdk

# ANDROID_SDK_ROOT is deprecated. Remove a user-scoped copy to avoid future conflicts.
$legacyUserSdkRoot = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User')
if ($legacyUserSdkRoot) {
    [Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $null, 'User')
    Write-Log 'Removed deprecated user ANDROID_SDK_ROOT; ANDROID_HOME is now authoritative.' 'CONFIG'
}
if (Test-Path Env:ANDROID_SDK_ROOT) {
    Remove-Item Env:ANDROID_SDK_ROOT -ErrorAction SilentlyContinue
}

$legacyMachineSdkRoot = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'Machine')
if (
    $legacyMachineSdkRoot -and
    (Normalize-PathEntry $legacyMachineSdkRoot) -ine (Normalize-PathEntry $AndroidSdk)
) {
    Write-Log "Machine ANDROID_SDK_ROOT points somewhere else ($legacyMachineSdkRoot). ANDROID_HOME is using $AndroidSdk." 'WARN'
}

Write-Log 'Checking Android CLI...' 'CHECK'
$AndroidCli = Find-AndroidCli
if (-not $AndroidCli) {
    $AndroidCli = Install-AndroidCli
    Write-Log "Android CLI installed at $AndroidCli" 'OK'
}
else {
    Write-Log "Android CLI found at $AndroidCli" 'OK'
}

$platformTools = Join-Path $AndroidSdk 'platform-tools\adb.exe'
$platformJar = Join-Path $AndroidSdk "platforms\android-$CompileSdk\android.jar"
$buildTools = if ($BuildToolsVersion) { Join-Path $AndroidSdk "build-tools\$BuildToolsVersion\aapt2.exe" } else { $null }
if (-not $BuildToolsVersion) {
    Write-Log 'Build Tools version is managed by the Android Gradle Plugin.' 'INFO'
}

function Get-MissingSdkPackages {
    $missing = @()

    if (-not (Test-Path -LiteralPath $platformTools -PathType Leaf)) {
        $missing += 'platform-tools'
    }
    if (-not (Test-Path -LiteralPath $platformJar -PathType Leaf)) {
        $missing += "platforms/android-$CompileSdk"
    }
    if ($buildTools -and -not (Test-Path -LiteralPath $buildTools -PathType Leaf)) {
        $missing += "build-tools/$BuildToolsVersion"
    }

    return $missing
}

$missingPackages = @(Get-MissingSdkPackages)

if ($missingPackages.Count -gt 0) {
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        Write-Log "Installing missing Android SDK packages: $($missingPackages -join ', ')" 'INSTALL'

        # Android CLI is still young and can occasionally exit abnormally on
        # Windows after all packages have already been written. Disable metrics,
        # then trust the filesystem verification below over the process exit code.
        & $AndroidCli '--no-metrics' "--sdk=$AndroidSdk" sdk install @missingPackages
        $sdkInstallExitCode = $LASTEXITCODE
        $missingAfterInstall = @(Get-MissingSdkPackages)

        if ($missingAfterInstall.Count -eq 0) {
            if ($sdkInstallExitCode -ne 0) {
                Write-Log "Android CLI exited with code $sdkInstallExitCode after installation, but all required SDK files were verified. Continuing." 'WARN'
            }
            else {
                Write-Log 'Android SDK packages installed and verified.' 'OK'
            }
            break
        }

        if ($attempt -lt 2) {
            Write-Log "SDK installation was incomplete; retrying once for: $($missingAfterInstall -join ', ')" 'WARN'
            $missingPackages = $missingAfterInstall
            Start-Sleep -Seconds 1
            continue
        }

        throw "Android SDK installation failed. Still missing: $($missingAfterInstall -join ', ')"
    }
}
else {
    Write-Log 'Required Android SDK packages are already installed; no SDK download is needed.' 'OK'
}

$requiredFiles = @($platformTools, $platformJar)
if ($buildTools) { $requiredFiles += $buildTools }
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required Android SDK component is still missing: $requiredFile"
    }
}

Add-ToUserPath @(
    (Join-Path $JavaHome 'bin'),
    (Join-Path $AndroidSdk 'platform-tools'),
    (Split-Path $AndroidCli -Parent)
)
Refresh-ProcessPath

Write-Host ''
Write-Log 'Environment setup complete.' 'OK'
Write-Host "JAVA_HOME=$JavaHome" -ForegroundColor DarkGray
Write-Host "ANDROID_HOME=$AndroidSdk" -ForegroundColor DarkGray
