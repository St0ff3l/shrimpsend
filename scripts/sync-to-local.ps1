#Requires -Version 5.1
# 从 ops 仓同步本地调试配置到业务仓，并初始化 MySQL 库
# 用法（在业务仓根目录）:
#   .\scripts\sync-to-local.ps1              # 同步配置 + 建库/迁移
#   .\scripts\sync-to-local.ps1 -SkipDb      # 仅同步配置
#   $env:ULTRASEND_OPS_DIR = 'D:\ops'; .\scripts\sync-to-local.ps1
param(
    [switch] $SkipDb,
    [switch] $Help
)

$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib\ops-common.ps1')

if ($Help) {
    Write-Output "用法: $($MyInvocation.MyCommand.Name) [-SkipDb]"
    Write-Output '  同步 ops/local/ 配置到业务仓，可选初始化 MySQL（ultrasend + ultrasend_overseas）'
    exit 0
}

$unknownArgs = $args | Where-Object { $_ -notin @('-SkipDb', '--skip-db') }
if ($unknownArgs) {
    Write-Error "未知参数: $($unknownArgs -join ' ')"
    exit 1
}

if ($args -contains '--skip-db') {
    $SkipDb = $true
}

$OpsDir = Resolve-UltrasendOpsDir -Root $Root
$LocalDir = Join-Path $OpsDir 'local'

if (-not (Test-Path -LiteralPath $LocalDir -PathType Container)) {
    [Console]::Error.WriteLine("错误: ops/local 目录不存在: $LocalDir")
    [Console]::Error.WriteLine('请在 ops 仓创建 local/（见 ops/README.md 或 clone public-ops 到 ../ops）')
    exit 1
}

function Copy-ConfigFile {
    param(
        [string] $Source,
        [string] $Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        Write-Output ('  [跳过] 源文件不存在: ' + $Source)
        return
    }

    $parent = Split-Path -Parent $Destination
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Output "  $Destination"
}

function Get-EnvFileValue {
    param(
        [string] $FilePath,
        [string] $Key
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return $null
    }

    foreach ($line in Get-Content -LiteralPath $FilePath) {
        if ($line -match '^\s*#') { continue }
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*)$") {
            $value = $Matches[1].Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            return $value
        }
    }

    return $null
}

function Test-DockerMysqlRunning {
    param([string] $ComposeFile)

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return $false
    }

    $status = & docker compose -f $ComposeFile ps mysql 2>$null
    return ($status -match 'Up')
}

function Invoke-MysqlExec {
    param(
        [string] $Sql,
        [string] $MysqlHost,
        [string] $MysqlPort,
        [string] $MysqlUser,
        [string] $MysqlPassword,
        [string] $ComposeFile
    )

    if (Get-Command mysql -ErrorAction SilentlyContinue) {
        $prevPwd = $env:MYSQL_PWD
        try {
            if ($MysqlPassword) {
                $env:MYSQL_PWD = $MysqlPassword
            }
            else {
                Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
            }
            & mysql -h $MysqlHost -P $MysqlPort -u $MysqlUser -e $Sql
            return $true
        }
        finally {
            if ($null -ne $prevPwd) {
                $env:MYSQL_PWD = $prevPwd
            }
            else {
                Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
            }
        }
    }

    if (Test-DockerMysqlRunning -ComposeFile $ComposeFile) {
        $dockerArgs = @('compose', '-f', $ComposeFile, 'exec', '-T', 'mysql', 'mysql', "-u$MysqlUser")
        if ($MysqlPassword) {
            $dockerArgs += "-p$MysqlPassword"
        }
        $dockerArgs += @('-e', $Sql)
        & docker @dockerArgs
        return $true
    }

    [Console]::Error.WriteLine('  [警告] 未找到 mysql CLI，且 docker compose mysql 未运行；请手动建库：')
    [Console]::Error.WriteLine('    CREATE DATABASE ultrasend;')
    [Console]::Error.WriteLine('    CREATE DATABASE ultrasend_overseas;')
    return $false
}

function Invoke-MysqlExecFile {
    param(
        [string] $FilePath,
        [string] $MysqlHost,
        [string] $MysqlPort,
        [string] $MysqlUser,
        [string] $MysqlPassword,
        [string] $ComposeFile
    )

    $sql = Get-Content -LiteralPath $FilePath -Raw

    if (Get-Command mysql -ErrorAction SilentlyContinue) {
        $prevPwd = $env:MYSQL_PWD
        try {
            if ($MysqlPassword) {
                $env:MYSQL_PWD = $MysqlPassword
            }
            else {
                Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
            }
            $sql | & mysql -h $MysqlHost -P $MysqlPort -u $MysqlUser
            return $true
        }
        finally {
            if ($null -ne $prevPwd) {
                $env:MYSQL_PWD = $prevPwd
            }
            else {
                Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
            }
        }
    }

    if (Test-DockerMysqlRunning -ComposeFile $ComposeFile) {
        $dockerArgs = @('compose', '-f', $ComposeFile, 'exec', '-T', 'mysql', 'mysql', "-u$MysqlUser")
        if ($MysqlPassword) {
            $dockerArgs += "-p$MysqlPassword"
        }
        $sql | & docker @dockerArgs
        return $true
    }

    return $false
}

Write-Output "==> 同步本地调试配置 from $LocalDir"

$configJson = Join-Path $LocalDir 'config.json'
if (Test-Path -LiteralPath $configJson -PathType Leaf) {
    Copy-ConfigFile $configJson (Join-Path $Root 'config.json')
}

$overseasYml = Join-Path $LocalDir 'application-dev-overseas.yml'
if (Test-Path -LiteralPath $overseasYml -PathType Leaf) {
    Copy-ConfigFile $overseasYml (Join-Path $Root 'backend\src\main\resources\application-dev-overseas.yml')
}

$backendEnv = Join-Path $LocalDir 'backend.env'
if (Test-Path -LiteralPath $backendEnv -PathType Leaf) {
    Copy-ConfigFile $backendEnv (Join-Path $Root 'backend\.env')
}

$dockerEnv = Join-Path $LocalDir 'docker.env'
if (Test-Path -LiteralPath $dockerEnv -PathType Leaf) {
    Copy-ConfigFile $dockerEnv (Join-Path $Root '.env')
}

$webEnvLocal = Join-Path $LocalDir 'web\.env.local'
$opsWebEnvLocal = Join-Path $OpsDir 'web\.env.local'
if (Test-Path -LiteralPath $webEnvLocal -PathType Leaf) {
    Copy-ConfigFile $webEnvLocal (Join-Path $Root 'web\.env.local')
}
elseif (Test-Path -LiteralPath $opsWebEnvLocal -PathType Leaf) {
    Copy-ConfigFile $opsWebEnvLocal (Join-Path $Root 'web\.env.local')
}

$localFlutterSecrets = Join-Path $LocalDir 'flutter\env.secrets.dart'
$opsFlutterSecrets = Join-Path $OpsDir 'flutter\env.secrets.dart'
if (Test-Path -LiteralPath $localFlutterSecrets -PathType Leaf) {
    Copy-ConfigFile $localFlutterSecrets (Join-Path $Root 'app\lib\config\env.secrets.dart')
}
elseif (Test-Path -LiteralPath $opsFlutterSecrets -PathType Leaf) {
    Copy-ConfigFile $opsFlutterSecrets (Join-Path $Root 'app\lib\config\env.secrets.dart')
}

$localOpenpanelSecrets = Join-Path $LocalDir 'flutter\openpanel_env.secrets.dart'
$opsOpenpanelSecrets = Join-Path $OpsDir 'flutter\openpanel_env.secrets.dart'
if (Test-Path -LiteralPath $localOpenpanelSecrets -PathType Leaf) {
    Copy-ConfigFile $localOpenpanelSecrets (Join-Path $Root 'app\lib\config\openpanel_env.secrets.dart')
}
elseif (Test-Path -LiteralPath $opsOpenpanelSecrets -PathType Leaf) {
    Copy-ConfigFile $opsOpenpanelSecrets (Join-Path $Root 'app\lib\config\openpanel_env.secrets.dart')
}

if ($SkipDb) {
    Write-Output '==> 已跳过数据库初始化 (-SkipDb)'
}
else {
    Write-Output '==> 初始化 MySQL 库'

    $mysqlHost = if ($env:MYSQL_HOST) { $env:MYSQL_HOST } else { '127.0.0.1' }
    $mysqlPort = if ($env:MYSQL_PORT) { $env:MYSQL_PORT } else { '3306' }
    $mysqlUser = if ($env:MYSQL_USER) { $env:MYSQL_USER } else { 'root' }
    $mysqlPassword = if ($null -ne $env:MYSQL_PASSWORD) { $env:MYSQL_PASSWORD } else { '' }

    $backendEnvPath = Join-Path $Root 'backend\.env'
    if (Test-Path -LiteralPath $backendEnvPath -PathType Leaf) {
        $dsUser = Get-EnvFileValue -FilePath $backendEnvPath -Key 'SPRING_DATASOURCE_USERNAME'
        $dsPassword = Get-EnvFileValue -FilePath $backendEnvPath -Key 'SPRING_DATASOURCE_PASSWORD'
        if ($dsUser) { $mysqlUser = $dsUser }
        if ($null -ne $dsPassword) { $mysqlPassword = $dsPassword }
    }

    $composeFile = Join-Path $Root 'docker-compose.yml'
    $createUltrasend = 'CREATE DATABASE IF NOT EXISTS ultrasend CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    $createOverseas = 'CREATE DATABASE IF NOT EXISTS ultrasend_overseas CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'

    if (-not (Invoke-MysqlExec -Sql $createUltrasend -MysqlHost $mysqlHost -MysqlPort $mysqlPort -MysqlUser $mysqlUser -MysqlPassword $mysqlPassword -ComposeFile $composeFile)) {
        [Console]::Error.WriteLine('  [警告] 无法连接 MySQL，请手动建库或稍后重试（可用 -SkipDb 仅同步配置）')
    }
    else {
        Write-Output '  数据库 ultrasend 就绪'
        Invoke-MysqlExec -Sql $createOverseas -MysqlHost $mysqlHost -MysqlPort $mysqlPort -MysqlUser $mysqlUser -MysqlPassword $mysqlPassword -ComposeFile $composeFile | Out-Null
        Write-Output '  数据库 ultrasend_overseas 就绪'

        $schemaFile = Join-Path $Root 'backend\scripts\schema.sql'
        if ((Test-Path -LiteralPath $schemaFile -PathType Leaf) -and
            (Invoke-MysqlExecFile -FilePath $schemaFile -MysqlHost $mysqlHost -MysqlPort $mysqlPort -MysqlUser $mysqlUser -MysqlPassword $mysqlPassword -ComposeFile $composeFile)) {
            Write-Output '  已执行 backend/scripts/schema.sql（ultrasend）'
        }
    }

    Write-Output '  ultrasend_overseas 表结构将在首次 ./scripts/start-dev.sh --overseas 时由 JPA ddl-auto 创建'
    Write-Output '  若从旧库升级，请手动对 ultrasend_overseas 执行 backend/scripts/migration-overseas-shrimpsend-upgrade.sql'
}

Write-Output ''
Write-Output '==> 完成'
Write-Output ''
Write-Output '下一步（在业务仓根目录）:'
Write-Output '  国内本地:  ./scripts/start-dev.sh'
Write-Output '  海外本地:  ./scripts/start-dev.sh --overseas'
Write-Output '  Stripe Webhook: stripe listen --forward-to localhost:9000/api/membership/stripe/webhook'
