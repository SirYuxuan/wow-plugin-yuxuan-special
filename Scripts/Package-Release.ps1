param(
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE "Desktop")
)

$ErrorActionPreference = "Stop"

function Get-TocFile {
    param(
        [string]$RootPath
    )

    $tocFiles = Get-ChildItem -Path $RootPath -Filter "*.toc" -File
    if ($tocFiles.Count -ne 1) {
        throw "Expected exactly one .toc file in $RootPath, found $($tocFiles.Count)."
    }

    return $tocFiles[0]
}

function Get-VersionFromToc {
    param(
        [string]$TocPath
    )

    $versionLine = Get-Content -Path $TocPath | Where-Object { $_ -match '^## Version:\s*(.+)$' } | Select-Object -First 1
    if (-not $versionLine) {
        throw "Could not find version in $TocPath."
    }

    return $Matches[1].Trim()
}

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$tocFile = Get-TocFile -RootPath $repoRoot
$addonName = [System.IO.Path]::GetFileNameWithoutExtension($tocFile.Name)
$version = Get-VersionFromToc -TocPath $tocFile.FullName

$stagingDir = Join-Path $DestinationRoot $addonName
$zipPath = Join-Path $DestinationRoot ("{0}-{1}.zip" -f $addonName, $version)

if (Test-Path -LiteralPath $stagingDir) {
    Remove-Item -LiteralPath $stagingDir -Recurse -Force
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

New-Item -ItemType Directory -Path $stagingDir | Out-Null

$robocopyArgs = @(
    $repoRoot,
    $stagingDir,
    "/E",
    "/R:1",
    "/W:1",
    "/XD", ".git", "Scripts",
    "/XF", "*.md", ".gitignore"
)

& robocopy @robocopyArgs | Out-Null
if ($LASTEXITCODE -gt 7) {
    throw "Robocopy failed with exit code $LASTEXITCODE."
}

Compress-Archive -Path $stagingDir -DestinationPath $zipPath -Force

Write-Output ("Folder: {0}" -f $stagingDir)
Write-Output ("Zip: {0}" -f $zipPath)
