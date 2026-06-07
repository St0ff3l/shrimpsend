#Requires -Version 5.1
# 兼容入口：请使用业务仓 .\scripts\sync-to-local.ps1
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
& (Join-Path $Root 'scripts\sync-to-local.ps1') @args
