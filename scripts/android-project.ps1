Set-StrictMode -Version Latest

function Get-AndroidApplicationModule {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [string]$Module = ''
    )

    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $buildFiles = @()

    if ($Module) {
        $relative = $Module.Trim().Trim(':').Replace(':', [IO.Path]::DirectorySeparatorChar)
        $modulePath = Join-Path $root $relative
        foreach ($name in @('build.gradle.kts', 'build.gradle')) {
            $candidate = Join-Path $modulePath $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $buildFiles += Get-Item -LiteralPath $candidate }
        }
        if ($buildFiles.Count -eq 0) { throw "Android module '$Module' was not found. Use its relative path or Gradle path, such as app or :mobile." }
    }
    else {
        $buildFiles = @(Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction Stop |
            Where-Object {
                $_.Name -in @('build.gradle.kts', 'build.gradle') -and
                $_.FullName -notmatch '[\\/](\.git|\.gradle|build)[\\/]'
            } |
            Where-Object {
                $applicationLines = @(Get-Content -LiteralPath $_.FullName | Where-Object {
                    $_ -match '(id\s*\(?\s*["'']com\.android\.application["'']|apply\s+plugin\s*:\s*["'']com\.android\.application["''])' -and
                    $_ -notmatch '\bapply\s+false\b'
                })
                $applicationLines.Count -gt 0
            })
    }

    if ($buildFiles.Count -ne 1) {
        if ($buildFiles.Count -eq 0) { throw 'No Android application module was found. Apply com.android.application in the module build file, or pass -Module.' }
        $choices = $buildFiles | ForEach-Object { Split-Path $_.DirectoryName -Leaf }
        throw "Multiple Android application modules were found ($($choices -join ', ')). Choose one with -Module."
    }

    $modulePath = $buildFiles[0].DirectoryName
    $relativePath = $modulePath.Substring($root.TrimEnd('\', '/').Length).TrimStart('\', '/')
    $gradlePath = if ($relativePath) { ':' + (($relativePath -split '[\\/]') -join ':') } else { '' }
    return [pscustomobject]@{
        Path = $modulePath
        RelativePath = $relativePath
        GradlePath = $gradlePath
        BuildFile = $buildFiles[0].FullName
    }
}

function Get-AndroidProjectRequirements {
    param([Parameter(Mandatory)]$ModuleInfo)

    $content = Get-Content -LiteralPath $ModuleInfo.BuildFile -Raw
    $compileSdk = $null
    foreach ($pattern in @(
        '(?m)^\s*compileSdk\s*=\s*(\d+)',
        '(?m)^\s*compileSdk\s+(\d+)',
        '(?m)^\s*compileSdkVersion\s*\(?\s*(\d+)'
    )) {
        if ($content -match $pattern) { $compileSdk = [int]$Matches[1]; break }
    }
    if (-not $compileSdk) { throw "Could not read compileSdk from $($ModuleInfo.BuildFile). Pass -CompileSdk explicitly."
    }

    $buildToolsVersion = $null
    if ($content -match '(?m)^\s*buildToolsVersion\s*(?:=|\s)\s*["'']([^"'']+)["'']') {
        $buildToolsVersion = $Matches[1]
    }
    return [pscustomobject]@{ CompileSdk = $compileSdk; BuildToolsVersion = $buildToolsVersion }
}

function Get-AndroidProjectName {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    foreach ($name in @('settings.gradle.kts', 'settings.gradle')) {
        $path = Join-Path $ProjectRoot $name
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $content = Get-Content -LiteralPath $path -Raw
            if ($content -match '(?m)^\s*rootProject\.name\s*=\s*["'']([^"'']+)["'']') { return $Matches[1] }
        }
    }
    return Split-Path (Resolve-Path -LiteralPath $ProjectRoot).Path -Leaf
}
