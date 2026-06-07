#Requires -Version 5.1
# 本地调试一键部署：从 ops/local 同步配置并初始化 MySQL
& (Join-Path $PSScriptRoot 'sync-to-local.ps1') @args
