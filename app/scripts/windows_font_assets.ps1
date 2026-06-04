#Requires -Version 5.1
<#
  Enable/disable bundled WenYuan font for Windows Flutter builds only.
  Usage:
    .\app\scripts\windows_font_assets.ps1 enable|disable|status
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('enable', 'disable', 'status')]
    [string] $Action
)

$ErrorActionPreference = 'Stop'
$AppDir = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $AppDir
$Pubspec = Join-Path $AppDir 'pubspec.yaml'
$FontFile = Join-Path $AppDir 'assets\fonts\windows\WenYuanSansSCVF.ttf'
$BeginMarker = '  # BEGIN_WINDOWS_FONT'
$EndMarker = '  # END_WINDOWS_FONT'
$EnabledBlock = @"
  fonts:
    - family: UltrasendWenYuanSansSC
      fonts:
        - asset: assets/fonts/windows/WenYuanSansSCVF.ttf
"@

function Read-PubspecText {
    return [System.IO.File]::ReadAllText($Pubspec, [System.Text.UTF8Encoding]::new($false))
}

function Write-PubspecText([string] $Text) {
    [System.IO.File]::WriteAllText($Pubspec, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Replace-FontBlock([string] $Text, [string] $Inner) {
    $begin = $Text.IndexOf($BeginMarker)
    $end = $Text.IndexOf($EndMarker)
    if ($begin -lt 0 -or $end -lt 0 -or $end -lt $begin) {
        throw "Font markers not found in $Pubspec"
    }
    $before = $Text.Substring(0, $begin + $BeginMarker.Length)
    $after = $Text.Substring($end + $EndMarker.Length)
    $body = if ($Inner.Trim()) { "`n$($Inner.TrimEnd())`n" } else { "`n" }
    return "$before$body$EndMarker$after"
}

function Test-FontEnabled {
    $text = Read-PubspecText
    $begin = $text.IndexOf($BeginMarker)
    $end = $text.IndexOf($EndMarker)
    if ($begin -lt 0 -or $end -lt 0) { return $false }
    $inner = $text.Substring($begin + $BeginMarker.Length, $end - $begin - $BeginMarker.Length).Trim()
    return $inner -match 'fonts:'
}

function Ensure-FontFile {
    if ((Test-Path -LiteralPath $FontFile) -and ((Get-Item -LiteralPath $FontFile).Length -gt 1000000)) {
        return
    }
    $fontDir = Split-Path -Parent $FontFile
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    $url = 'https://github.com/takushun-wu/WenYuanFonts/releases/download/2026.5.22/WenYuanSansSCVF.ttf'
    Write-Host "Downloading WenYuan Sans SC VF..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $FontFile -UseBasicParsing
    } catch {
        throw "Font file missing at $FontFile and download failed: $_"
    }
    if (-not (Test-Path -LiteralPath $FontFile) -or (Get-Item -LiteralPath $FontFile).Length -lt 1000000) {
        throw "Font download incomplete: $FontFile"
    }
}

switch ($Action) {
    'status' {
        if (Test-FontEnabled) { Write-Output 'enabled' } else { Write-Output 'disabled' }
    }
    'enable' {
        Ensure-FontFile
        Write-PubspecText (Replace-FontBlock (Read-PubspecText) $EnabledBlock)
        Write-Host 'pubspec: Windows font enabled'
    }
    'disable' {
        Write-PubspecText (Replace-FontBlock (Read-PubspecText) '')
        Write-Host 'pubspec: Windows font disabled'
    }
}
