#Requires -Version 5.1
<#
  转发至 app/scripts/package_windows.ps1（统一入口）。用法与参数与原脚本一致。
  推荐直接使用: .\app\scripts\package_windows.ps1
#>
param(
    [switch] $SkipMsix,
    [switch] $SkipInno,
    [switch] $ZipOnly,
    [switch] $SkipClean,
    [switch] $Overseas,
    [switch] $All
)

$ErrorActionPreference = 'Stop'
$Target = Join-Path (Split-Path -Parent $PSScriptRoot) 'app\scripts\package_windows.ps1'
& $Target @PSBoundParameters
