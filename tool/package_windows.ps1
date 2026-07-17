[CmdletBinding()]
param(
    [string]$Version,
    [switch]$SkipChecks,
    [switch]$SkipRootDeploy
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $projectRoot

if (-not $Version) {
    $versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*([^+\s]+)' | Select-Object -First 1
    if (-not $versionLine) {
        throw 'Unable to read the version from pubspec.yaml.'
    }
    $Version = $versionLine.Matches[0].Groups[1].Value
}

if (-not $SkipChecks) {
    flutter pub get
    flutter analyze
    flutter test
}

flutter build windows --release

$bundleSource = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$executable = Join-Path $bundleSource 'cherry_token_monitor.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Release executable not found: $executable"
}

# Keep the convenient executable at the repository root runnable. A Flutter
# Windows executable is not standalone: its matching DLLs and data directory
# must be deployed together from the same build.
if (-not $SkipRootDeploy) {
    Copy-Item -Path (Join-Path $bundleSource '*') -Destination $projectRoot -Recurse -Force
}

$distDir = Join-Path $projectRoot 'dist'
$packageName = "CherryTokenMonitor-$Version-windows-x64"
$stageDir = Join-Path $distDir $packageName
$archivePath = Join-Path $distDir "$packageName.zip"
$hashPath = "$archivePath.sha256"

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
if (Test-Path -LiteralPath $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
}
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

New-Item -ItemType Directory -Path $stageDir | Out-Null
Copy-Item -Path (Join-Path $bundleSource '*') -Destination $stageDir -Recurse -Force
Compress-Archive -Path $stageDir -DestinationPath $archivePath -CompressionLevel Optimal

$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $hashPath -Value "$hash *$packageName.zip" -Encoding ascii

Write-Host "Package: $archivePath"
Write-Host "SHA-256: $hash"
if (-not $SkipRootDeploy) {
    Write-Host "Local runnable: $projectRoot\cherry_token_monitor.exe"
}
