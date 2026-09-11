param(
    [string]$Alias = 'release',
    [string]$KeystoreRelativePath = 'signing/release.p12',
    [int]$KeySize = 3072,
    [int]$ValidityDays = 10000,
    [int]$MinimumPasswordLength = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PropertiesPath = Join-Path $PSScriptRoot 'keystore.properties'
$KeystorePath = Join-Path $PSScriptRoot ($KeystoreRelativePath -replace '/', '\')
$SigningDirectory = Split-Path -Parent $KeystorePath

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('CHECK', 'CONFIG', 'CREATE', 'OK', 'WARN', 'ERROR')]
        [string]$Type = 'CHECK'
    )

    $color = switch ($Type) {
        'CHECK'  { 'DarkCyan' }
        'CONFIG' { 'Cyan' }
        'CREATE' { 'Yellow' }
        'OK'     { 'Green' }
        'WARN'   { 'Yellow' }
        'ERROR'  { 'Red' }
        default  { 'Gray' }
    }

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -ForegroundColor DarkGray -NoNewline
    Write-Host "[$Type] " -ForegroundColor $color -NoNewline
    Write-Host $Message
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Argument)

    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
        return $Argument
    }

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

function Get-Keytool {
    $javaHomes = @(
        $env:JAVA_HOME,
        [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User'),
        [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    ) | Where-Object { $_ }

    foreach ($javaHomeCandidate in ($javaHomes | Select-Object -Unique)) {
        $candidate = Join-Path $javaHomeCandidate 'bin\keytool.exe'
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $command = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

function Convert-SecureStringToPlainText {
    param([Parameter(Mandatory)][Security.SecureString]$SecureString)

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Read-StrongPassword {
    while ($true) {
        $firstSecure = Read-Host "Release signing password (minimum $MinimumPasswordLength characters)" -AsSecureString
        $first = Convert-SecureStringToPlainText $firstSecure

        if ($first.Length -lt $MinimumPasswordLength) {
            Write-Log "Password must be at least $MinimumPasswordLength characters." 'WARN'
            $first = $null
            continue
        }

        $secondSecure = Read-Host 'Confirm password' -AsSecureString
        $second = Convert-SecureStringToPlainText $secondSecure

        if ($first -cne $second) {
            Write-Log 'Passwords do not match. Try again.' 'WARN'
            $first = $null
            $second = $null
            continue
        }

        $second = $null
        return $first
    }
}

function Escape-JavaPropertyValue {
    param([Parameter(Mandatory)][string]$Value)

    $builder = [Text.StringBuilder]::new()

    for ($i = 0; $i -lt $Value.Length; $i++) {
        $char = $Value[$i]
        $code = [int]$char

        switch ($char) {
            '\'  { $null = $builder.Append('\\'); continue }
            "`t" { $null = $builder.Append('\t'); continue }
            "`n" { $null = $builder.Append('\n'); continue }
            "`r" { $null = $builder.Append('\r'); continue }
            "`f" { $null = $builder.Append('\f'); continue }
            '='  { $null = $builder.Append('\='); continue }
            ':'  { $null = $builder.Append('\:'); continue }
            '#'  { $null = $builder.Append('\#'); continue }
            '!'  { $null = $builder.Append('\!'); continue }
            ' ' {
                if ($i -eq 0) {
                    $null = $builder.Append('\ ')
                }
                else {
                    $null = $builder.Append(' ')
                }
                continue
            }
        }

        if ($code -gt 255) {
            $null = $builder.Append(('\u{0:X4}' -f $code))
        }
        else {
            $null = $builder.Append($char)
        }
    }

    return $builder.ToString()
}

function Write-KeystoreProperties {
    param(
        [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][string]$KeyAlias
    )

    $relative = $KeystoreRelativePath -replace '\\', '/'

    $lines = @(
        'storeType=PKCS12'
        "storeFile=$(Escape-JavaPropertyValue $relative)"
        "storePassword=$(Escape-JavaPropertyValue $Password)"
        "keyAlias=$(Escape-JavaPropertyValue $KeyAlias)"
        "keyPassword=$(Escape-JavaPropertyValue $Password)"
        ''
    )

    # java.util.Properties.load(InputStream) uses ISO-8859-1 semantics.
    $encoding = [Text.Encoding]::GetEncoding(28591)
    [IO.File]::WriteAllText($PropertiesPath, ($lines -join [Environment]::NewLine), $encoding)
}

function Test-IgnoreRules {
    $gitignore = Join-Path $PSScriptRoot '.gitignore'
    if (-not (Test-Path -LiteralPath $gitignore)) {
        throw '.gitignore is missing. Refusing to create private signing material.'
    }

    $lines = @(Get-Content -LiteralPath $gitignore | ForEach-Object { $_.Trim() })

    $propertiesIgnored = $lines -contains 'keystore.properties'
    $signingIgnored =
        ($lines -contains 'signing/') -or
        ($lines -contains 'signing') -or
        ($lines -contains '*.p12') -or
        ($lines -contains '*.jks') -or
        ($lines -contains '*.keystore')

    if (-not $propertiesIgnored -or -not $signingIgnored) {
        throw 'Private signing files are not safely ignored. Ensure .gitignore contains keystore.properties and signing/ (or *.p12).'
    }
}

function Get-ExistingSigningConfig {
    if (-not (Test-Path -LiteralPath $PropertiesPath)) {
        return $null
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $PropertiesPath) {
        if ($line -match '^\s*[#!]') {
            continue
        }

        if ($line -match '^\s*([^:=\s]+)\s*[:=]\s*(.*)$') {
            $values[$Matches[1]] = $Matches[2].Trim()
        }
    }

    return $values
}

Write-Log 'Checking release-signing prerequisites...' 'CHECK'
Test-IgnoreRules

$keytool = Get-Keytool
if (-not $keytool) {
    throw 'keytool.exe was not found. Run .\setup.ps1 first, then run .\setup-keys.ps1.'
}
Write-Log "Using keytool: $keytool" 'OK'

$existingConfig = Get-ExistingSigningConfig
if ($existingConfig) {
    $existingStoreFile = $existingConfig['storeFile']

    if ($existingStoreFile) {
        $existingPath = Join-Path $PSScriptRoot ($existingStoreFile -replace '/', '\')

        if (Test-Path -LiteralPath $existingPath) {
            $existingType = if ($existingConfig['storeType']) { $existingConfig['storeType'] } else { 'unspecified/JDK default' }

            Write-Host ''
            Write-Log 'Release signing is already configured.' 'WARN'
            Write-Host "Keystore: $existingPath" -ForegroundColor Cyan
            Write-Host "Type: $existingType" -ForegroundColor Cyan
            if ($existingConfig['keyAlias']) {
                Write-Host "Alias: $($existingConfig['keyAlias'])" -ForegroundColor Cyan
            }
            Write-Host ''
            Write-Host 'Nothing was changed.' -ForegroundColor Yellow
            Write-Host 'Because signing identity changes are consequential, this script never replaces an existing key.' -ForegroundColor Yellow
            Write-Host ''
            Write-Host 'If this app has never been distributed and you intentionally want a fresh PKCS12 identity:' -ForegroundColor DarkGray
            Write-Host '  1. Back up or remove the current keystore and keystore.properties.' -ForegroundColor DarkGray
            Write-Host '  2. Run .\setup-keys.ps1 again.' -ForegroundColor DarkGray
            return
        }
    }

    throw 'keystore.properties already exists but does not point to an existing keystore. Fix or remove it before creating a new signing identity.'
}

if (Test-Path -LiteralPath $KeystorePath) {
    throw "A keystore already exists at $KeystorePath. Refusing to overwrite it. Back it up or remove it intentionally, then rerun."
}

$aliasInput = Read-Host "Key alias [$Alias]"
if (-not [string]::IsNullOrWhiteSpace($aliasInput)) {
    $Alias = $aliasInput.Trim()
}

if ($Alias -notmatch '^[A-Za-z0-9._-]+$') {
    throw 'Key alias may contain only letters, numbers, dot, underscore and hyphen.'
}

New-Item -ItemType Directory -Path $SigningDirectory -Force | Out-Null

$password = $null

try {
    $password = Read-StrongPassword
    $env:PCAMPUS_RELEASE_PASSWORD = $password

    Write-Log 'Creating PKCS12 Android release signing key...' 'CREATE'

    $arguments = @(
        '-genkeypair',
        '-keystore', $KeystorePath,
        '-storetype', 'PKCS12',
        '-alias', $Alias,
        '-keyalg', 'RSA',
        '-keysize', "$KeySize",
        '-validity', "$ValidityDays",
        '-dname', 'CN=Campus Login Release',
        '-storepass:env', 'PCAMPUS_RELEASE_PASSWORD',
        '-keypass:env', 'PCAMPUS_RELEASE_PASSWORD'
    )

    $result = Invoke-NativeCaptured -FilePath $keytool -Arguments $arguments
    if ($result.ExitCode -ne 0) {
        $details = @($result.StdOut, $result.StdErr) |
            Where-Object { $_ } |
            ForEach-Object { $_.Trim() }

        throw "keytool failed to create the release key.`n$($details -join [Environment]::NewLine)"
    }

    if (-not (Test-Path -LiteralPath $KeystorePath -PathType Leaf)) {
        throw 'keytool reported success, but the PKCS12 keystore was not created.'
    }

    Write-Log 'Verifying PKCS12 keystore and alias...' 'CHECK'

    $verify = Invoke-NativeCaptured -FilePath $keytool -Arguments @(
        '-list',
        '-v',
        '-keystore', $KeystorePath,
        '-storetype', 'PKCS12',
        '-alias', $Alias,
        '-storepass:env', 'PCAMPUS_RELEASE_PASSWORD'
    )

    if ($verify.ExitCode -ne 0) {
        $details = @($verify.StdOut, $verify.StdErr) |
            Where-Object { $_ } |
            ForEach-Object { $_.Trim() }

        throw "The generated PKCS12 keystore could not be verified.`n$($details -join [Environment]::NewLine)"
    }

    Write-Log 'Writing keystore.properties...' 'CONFIG'
    Write-KeystoreProperties -Password $password -KeyAlias $Alias
}
catch {
    if ((Test-Path -LiteralPath $KeystorePath) -and -not (Test-Path -LiteralPath $PropertiesPath)) {
        Write-Log 'Setup failed after creating the keystore. The new keystore was left in place so it is not silently destroyed.' 'WARN'
    }
    throw
}
finally {
    Remove-Item Env:PCAMPUS_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    $password = $null
}

Write-Host ''
Write-Log 'Release signing is configured.' 'OK'
Write-Host ''
Write-Host "Keystore: $KeystorePath" -ForegroundColor Cyan
Write-Host 'Type: PKCS12' -ForegroundColor Cyan
Write-Host "Alias: $Alias" -ForegroundColor Cyan
Write-Host "Properties: $PropertiesPath" -ForegroundColor Cyan
