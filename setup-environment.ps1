[CmdletBinding()]
param([int]$MaximumJavaVersion = 24)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http

$AndroidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$CommandLineTools = Join-Path $AndroidSdk "cmdline-tools\latest"
$SdkManager = Join-Path $CommandLineTools "bin\sdkmanager.bat"
$JavaRoot = Join-Path $env:LOCALAPPDATA "Programs\Java"

$AndroidToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip"
$AndroidToolsSha256 = "90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a"
$OracleJdkUrl = "https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.zip"

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("CHECK", "INFO", "DOWNLOAD", "INSTALL", "CONFIG", "OK")]
        [string]$Type = "INFO"
    )

    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "[$time] [$Type] $Message"
}

function Invoke-Download {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Name
    )

    Write-Log "Starting $Name download..." "DOWNLOAD"
    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromMinutes(20)
    $response = $null
    $sourceStream = $null
    $fileStream = $null

    try {
        $option = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
        $response = $client.GetAsync($Uri, $option).GetAwaiter().GetResult()
        $null = $response.EnsureSuccessStatusCode()

        $totalBytes = $response.Content.Headers.ContentLength
        $sourceStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $fileStream = [System.IO.File]::Open(
            $Destination,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )

        $buffer = New-Object byte[] 1048576
        [long]$downloadedBytes = 0
        $lastLoggedPercent = -10
        $lastProgressUpdateMs = -1000
        $downloadTimer = [System.Diagnostics.Stopwatch]::StartNew()

        while (($bytesRead = $sourceStream.ReadAsync($buffer, 0, $buffer.Length).GetAwaiter().GetResult()) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
            $downloadedBytes += $bytesRead

            if ($totalBytes -gt 0) {
                $percent = [math]::Min(100, [int](($downloadedBytes * 100) / $totalBytes))
                $elapsedMs = $downloadTimer.ElapsedMilliseconds
                $seconds = [math]::Max(0.001, $downloadTimer.Elapsed.TotalSeconds)
                $megabytesPerSecond = ($downloadedBytes / 1MB) / $seconds

                if (($elapsedMs - $lastProgressUpdateMs) -ge 500 -or $percent -eq 100) {
                    $status = "$percent% - $($megabytesPerSecond.ToString('0.0')) MB/s"
                    Write-Progress -Activity "Downloading $Name" -Status $status -PercentComplete $percent
                    $lastProgressUpdateMs = $elapsedMs
                }

                if ($percent -ge ($lastLoggedPercent + 10)) {
                    Write-Log "$Name download: $percent% ($($megabytesPerSecond.ToString('0.0')) MB/s)" "DOWNLOAD"
                    $lastLoggedPercent = $percent
                }
            }
        }

        $downloadTimer.Stop()
        Write-Progress -Activity "Downloading $Name" -Completed
        if ($totalBytes -gt 0 -and $downloadedBytes -ne $totalBytes) { throw "Incomplete download: $Name" }
        Write-Log "$Name download complete." "OK"
    }
    finally {
        if ($fileStream) { $fileStream.Dispose() }
        if ($sourceStream) { $sourceStream.Dispose() }
        if ($response) { $response.Dispose() }
        $client.Dispose()
    }
}

function Test-JavaHome {
    param([string]$Path)

    if (-not $Path) {
        return $false
    }

    $javaExecutable = Join-Path $Path "bin\java.exe"
    $keytoolExecutable = Join-Path $Path "bin\keytool.exe"
    if (-not (Test-Path $javaExecutable) -or -not (Test-Path $keytoolExecutable) -or -not (Test-Path (Join-Path $Path "bin\javac.exe"))) {
        return $false
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $javaExecutable
    $startInfo.Arguments = "-version"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.CreateNoWindow = $true

    $javaProcess = [System.Diagnostics.Process]::new()
    $javaProcess.StartInfo = $startInfo
    $null = $javaProcess.Start()
    $versionText = $javaProcess.StandardError.ReadToEnd()
    if (-not $versionText) {
        $versionText = $javaProcess.StandardOutput.ReadToEnd()
    }
    $javaProcess.WaitForExit()
    $javaExitCode = $javaProcess.ExitCode
    $javaProcess.Dispose()
    if ($javaExitCode -ne 0) { return $false }

    if ($versionText -notmatch '"(?<version>[0-9]+)(?:\.(?<minor>[0-9]+))?') {
        return $false
    }

    $majorVersion = [int]$Matches.version
    if ($majorVersion -eq 1 -and $Matches.minor) {
        $majorVersion = [int]$Matches.minor
    }

    return $majorVersion -ge 17 -and $majorVersion -le $MaximumJavaVersion
}

function Get-JavaHome {
    $candidates = @(
        $env:JAVA_HOME
        [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
        [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
    )

    $javaCommands = Get-Command java.exe -All -ErrorAction SilentlyContinue
    foreach ($javaCommand in $javaCommands) {
        $candidates += Split-Path (Split-Path $javaCommand.Source -Parent) -Parent
    }

    $keytoolCommands = Get-Command keytool.exe -All -ErrorAction SilentlyContinue
    foreach ($keytoolCommand in $keytoolCommands) {
        $candidates += Split-Path (Split-Path $keytoolCommand.Source -Parent) -Parent
    }

    foreach ($searchRoot in @($JavaRoot, "$env:ProgramFiles\Java", "$env:ProgramFiles\Microsoft", "$env:ProgramFiles\Eclipse Adoptium")) {
        if (Test-Path -LiteralPath $searchRoot) { $candidates += @(Get-ChildItem -LiteralPath $searchRoot -Directory | ForEach-Object FullName) }
    }
    foreach ($candidate in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        Write-Log "Testing Java installation at $candidate" "CHECK"
        if (Test-JavaHome $candidate) {
            return $candidate
        }
    }

    return $null
}

function Add-ToUserPath {
    param([Parameter(Mandatory)][string[]]$Paths)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathEntries = @($currentPath -split ";" | Where-Object { $_ })

    foreach ($requiredPath in $Paths) {
        if ($pathEntries -notcontains $requiredPath) {
            $pathEntries += $requiredPath
            Write-Log "Added to user Path: $requiredPath" "CONFIG"
        }
        else {
            Write-Log "Already in user Path: $requiredPath" "CHECK"
        }
    }

    [Environment]::SetEnvironmentVariable("Path", ($pathEntries -join ";"), "User")
}

Write-Log "Checking for a complete JDK 17 through $MaximumJavaVersion..." "CHECK"
$JavaHome = Get-JavaHome

if (-not $JavaHome) {
    Write-Log "A compatible Java installation was not found." "INFO"
    $javaTemp = Join-Path ([System.IO.Path]::GetTempPath()) ("ioe-notices-jdk-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $javaTemp -Force | Out-Null

    try {
        $javaArchive = Join-Path $javaTemp "jdk.zip"
        Invoke-Download -Uri $OracleJdkUrl -Destination $javaArchive -Name "Oracle JDK 21"
        $checksumFile = Join-Path $javaTemp 'jdk.sha256'
        Invoke-Download -Uri ($OracleJdkUrl + '.sha256') -Destination $checksumFile -Name 'JDK checksum'
        $expectedHash = ((Get-Content -LiteralPath $checksumFile -Raw).Trim() -split '\s+')[0]
        if ($expectedHash -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $javaArchive -Algorithm SHA256).Hash -ne $expectedHash) { throw 'JDK checksum verification failed.' }

        Write-Log "Extracting Oracle JDK 21 to $JavaRoot..." "INSTALL"
        New-Item -ItemType Directory -Path $JavaRoot -Force | Out-Null
        Expand-Archive -LiteralPath $javaArchive -DestinationPath $JavaRoot -Force

        $JavaHome = Get-ChildItem -Path $JavaRoot -Directory |
            Where-Object { Test-JavaHome $_.FullName } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName

        if (-not $JavaHome) {
            throw "Oracle JDK was extracted, but a compatible JDK was not found."
        }

        Write-Log "Oracle JDK 21 installed at $JavaHome" "OK"
    }
    finally {
        if (Test-Path $javaTemp) {
            Write-Log "Removing temporary Java download files..." "INFO"
            $cleanupPath = [IO.Path]::GetFullPath($javaTemp)
            $cleanupRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
            if (-not $cleanupPath.StartsWith($cleanupRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup path.' }
            Remove-Item -LiteralPath $cleanupPath -Recurse -Force
        }
    }
}
else {
    Write-Log "Compatible Java found at $JavaHome" "OK"
}

Write-Log "Configuring JAVA_HOME..." "CONFIG"
$env:JAVA_HOME = $JavaHome
[Environment]::SetEnvironmentVariable("JAVA_HOME", $JavaHome, "User")
Write-Log "JAVA_HOME=$JavaHome" "OK"

Write-Log "Checking for Android command-line tools..." "CHECK"
if (-not (Test-Path $SdkManager)) {
    Write-Log "Android command-line tools were not found." "INFO"
    $androidTemp = Join-Path ([System.IO.Path]::GetTempPath()) ("ioe-notices-android-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $androidTemp -Force | Out-Null

    try {
        $androidArchive = Join-Path $androidTemp "command-line-tools.zip"
        $extractPath = Join-Path $androidTemp "extracted"
        Invoke-Download -Uri $AndroidToolsUrl -Destination $androidArchive -Name "Android command-line tools"

        Write-Log "Verifying Android command-line tools checksum..." "CHECK"
        $actualHash = (Get-FileHash -LiteralPath $androidArchive -Algorithm SHA256).Hash
        if ($actualHash -ne $AndroidToolsSha256) {
            throw "Android command-line tools checksum verification failed."
        }
        Write-Log "Checksum verified." "OK"

        Write-Log "Extracting Android command-line tools to $CommandLineTools..." "INSTALL"
        Expand-Archive -LiteralPath $androidArchive -DestinationPath $extractPath
        New-Item -ItemType Directory -Path $CommandLineTools -Force | Out-Null
        Copy-Item -Path (Join-Path $extractPath "cmdline-tools\*") -Destination $CommandLineTools -Recurse
    }
    finally {
        if (Test-Path $androidTemp) {
            Write-Log "Removing temporary Android download files..." "INFO"
            $cleanupPath = [IO.Path]::GetFullPath($androidTemp)
            $cleanupRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
            if (-not $cleanupPath.StartsWith($cleanupRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup path.' }
            Remove-Item -LiteralPath $cleanupPath -Recurse -Force
        }
    }

    if (-not (Test-Path $SdkManager)) {
        throw "Android tools were extracted, but sdkmanager.bat was not found."
    }

    Write-Log "Android command-line tools installed." "OK"
}
else {
    Write-Log "Android command-line tools found at $CommandLineTools" "OK"
}

Write-Log "Configuring Android environment variables..." "CONFIG"
$env:ANDROID_HOME = $AndroidSdk
$env:Path = "$JavaHome\bin;$AndroidSdk\platform-tools;$CommandLineTools\bin;$env:Path"
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $AndroidSdk, "User")
Add-ToUserPath @(
    "$JavaHome\bin"
    "$AndroidSdk\platform-tools"
    "$CommandLineTools\bin"
)
Write-Log "ANDROID_HOME=$AndroidSdk" "OK"

function Invoke-SdkSetup {
    param([string]$Arguments, [string]$Answer = 'y')
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $env:ComSpec
    $info.Arguments = '/d /s /c ""' + $SdkManager + '" --sdk_root="' + $AndroidSdk + '" ' + $Arguments + '"'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        $null = $process.Start()
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $errorTask = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTime]::UtcNow.AddMinutes(20)
        while (-not $process.WaitForExit(300)) {
            if ([DateTime]::UtcNow -gt $deadline) { $process.Kill(); throw 'SDK manager timed out.' }
            # sdkmanager can replace its buffered reader between prompts. Do not send all answers at once.
            try { $process.StandardInput.WriteLine($Answer); $process.StandardInput.Flush() } catch [IO.IOException] { }
        }
        $output = $outputTask.GetAwaiter().GetResult()
        $errors = $errorTask.GetAwaiter().GetResult()
        if ($errors) { Write-Host $errors }
        if ($process.ExitCode -ne 0) { throw "SDK manager failed: $($process.ExitCode)" }
        return $output
    } finally { $process.Dispose() }
}
Write-Log 'Accepting Android SDK licenses...' 'CONFIG'
Invoke-SdkSetup '--licenses' | Write-Host
$verification = Invoke-SdkSetup '--licenses' 'n'
if ($verification -notmatch 'All SDK package licenses accepted') { throw 'SDK licenses could not be verified.' }
Write-Log 'Installing Platform Tools, API 36 and Build Tools 36.0.0...' 'INSTALL'
Invoke-SdkSetup '"platform-tools" "platforms;android-36" "build-tools;36.0.0"' | Write-Host
foreach ($required in @('platform-tools\adb.exe','platforms\android-36\android.jar','build-tools\36.0.0\aapt2.exe')) {
    if (-not (Test-Path (Join-Path $AndroidSdk $required))) { throw "SDK package missing: $required" }
}
Write-Log "Android SDK licenses are configured." "OK"

Write-Host ""
Write-Log "Environment setup complete." "OK"
Write-Host "JAVA_HOME=$JavaHome"
Write-Host "ANDROID_HOME=$AndroidSdk"
Write-Host "Ready. Run .\apk.ps1 in this window."
