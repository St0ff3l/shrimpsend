#Requires -Version 5.1
<#
  Windows 构建：默认国内（OVERSEAS_BUILD=false）；加 -Overseas 为出海包。
  Usage（仓库根目录）:
    .\app\scripts\build-windows.ps1
    .\app\scripts\build-windows.ps1 -Overseas
  其余参数透传给 flutter build windows。
#>
param(
    [switch] $Overseas
)

$ErrorActionPreference = 'Stop'
$AppDir = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $AppDir
& (Join-Path $AppDir 'scripts\windows_font_assets.ps1') enable
$overseasDefine = if ($Overseas) { 'true' } else { 'false' }
flutter build windows --release "--dart-define=OVERSEAS_BUILD=$overseasDefine" @args
