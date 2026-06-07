#Requires -Version 5.1
<#
  pdfrx Windows 构建依赖 pdfium.dll。插件 CMake 在 configure 阶段从 GitHub 下载
  pdfium-win-x64.tgz 并用 cmake -E tar 解压；网络受限时易出现 0 字节包，导致后续 COPY 失败。

  本脚本在 flutter build windows 之前，将内置 pdfium（app/windows/pdfium_vendor）或可靠下载
  预置到 pdfrx 期望路径：build/windows/x64/pdfium/chromium%2F7202/

  Usage（app 目录）:
    .\scripts\ensure_windows_pdfium.ps1
#>
$ErrorActionPreference = 'Stop'

$AppDir = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { Get-Location }
$PdfiumReleaseDirName = 'chromium%2F7202'
$BuildPdfiumDir = Join-Path $AppDir "build\windows\x64\pdfium\$PdfiumReleaseDirName"
$VendorDir = Join-Path $AppDir 'windows\pdfium_vendor\x64'
$PdfiumDllName = 'pdfium.dll'
$PdfiumHeaderName = 'fpdfview.h'
$ArchiveName = 'pdfium-win-x64.tgz'
$DownloadUrl = "https://github.com/bblanchon/pdfium-binaries/releases/download/$PdfiumReleaseDirName/$ArchiveName"
$MinimumDllBytes = 1MB

function Test-PdfiumTree([string] $Root) {
    if ([string]::IsNullOrWhiteSpace($Root)) { return $false }
    $dll = Join-Path $Root "bin\$PdfiumDllName"
    $header = Join-Path $Root "include\$PdfiumHeaderName"
    if (-not (Test-Path -LiteralPath $dll)) { return $false }
    if (-not (Test-Path -LiteralPath $header)) { return $false }
    return (Get-Item -LiteralPath $dll).Length -ge $MinimumDllBytes
}

function Copy-PdfiumTree([string] $SourceRoot, [string] $DestRoot) {
    New-Item -ItemType Directory -Force -Path (Join-Path $DestRoot 'bin') | Out-Null
    Copy-Item -LiteralPath (Join-Path $SourceRoot "bin\$PdfiumDllName") `
        -Destination (Join-Path $DestRoot "bin\$PdfiumDllName") -Force
    $destInclude = Join-Path $DestRoot 'include'
    if (Test-Path -LiteralPath $destInclude) {
        Remove-Item -LiteralPath $destInclude -Recurse -Force
    }
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'include') -Destination $destInclude -Recurse -Force
}

function Install-PdfiumFromVendor {
    if (-not (Test-PdfiumTree $VendorDir)) {
        Write-Error "Built-in PDFium vendor tree is incomplete: $VendorDir"
    }
    Write-Host "PDFium -> $BuildPdfiumDir (from vendor)"
    Copy-PdfiumTree $VendorDir $BuildPdfiumDir
}

function Install-PdfiumFromDownload {
    New-Item -ItemType Directory -Force -Path $BuildPdfiumDir | Out-Null
    $archivePath = Join-Path $BuildPdfiumDir $ArchiveName
    if (Test-Path -LiteralPath $archivePath) {
        $size = (Get-Item -LiteralPath $archivePath).Length
        if ($size -lt 100KB) {
            Write-Host "Remove invalid PDFium archive ($size bytes): $archivePath"
            Remove-Item -LiteralPath $archivePath -Force
        }
    }

    if (-not (Test-Path -LiteralPath $archivePath)) {
        Write-Host "Download PDFium: $DownloadUrl"
        try {
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $archivePath -UseBasicParsing
        } catch {
            Write-Error "PDFium download failed: $_"
        }
    }

    $archiveSize = (Get-Item -LiteralPath $archivePath).Length
    if ($archiveSize -lt 100KB) {
        Write-Error "PDFium archive too small ($archiveSize bytes): $archivePath"
    }

    Write-Host "Extract PDFium -> $BuildPdfiumDir"
    Push-Location -LiteralPath $BuildPdfiumDir
    try {
        tar -zxf $ArchiveName
        if ($LASTEXITCODE -ne 0) {
            Write-Error "tar failed to extract PDFium (exit $LASTEXITCODE)"
        }
    } finally {
        Pop-Location
    }
}

if (Test-PdfiumTree $BuildPdfiumDir) {
    Write-Host "PDFium already present: $BuildPdfiumDir"
    exit 0
}

if (Test-PdfiumTree $VendorDir) {
    Install-PdfiumFromVendor
} else {
    Install-PdfiumFromDownload
}

if (-not (Test-PdfiumTree $BuildPdfiumDir)) {
    Write-Error "PDFium setup failed; expected bin\$PdfiumDllName under $BuildPdfiumDir"
}

Write-Host 'PDFium ready for pdfrx Windows build.'
