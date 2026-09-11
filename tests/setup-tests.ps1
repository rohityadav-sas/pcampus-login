# No downloads or environment mutation: exercise setup's JDK validation separately.
$ErrorActionPreference = 'Stop'
$MaximumJavaVersion = 24
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '../setup-environment.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Setup script does not parse.' }
$function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-JavaHome' }, $true)
Invoke-Expression $function.Extent.Text
if (Test-JavaHome '') { throw 'Empty Java path accepted.' }
if (Test-JavaHome $env:TEMP) { throw 'Non-JDK accepted.' }
if (-not (Test-JavaHome $env:JAVA_HOME)) { throw 'Installed complete JDK rejected.' }
$MaximumJavaVersion = 16
if (Test-JavaHome $env:JAVA_HOME) { throw 'Unsupported newer Java accepted.' }
Write-Host 'PASS: syntax, missing JDK, valid JDK, wrapper Java ceiling.'
