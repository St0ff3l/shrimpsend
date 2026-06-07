# Shared helpers for resolving and validating the ultrasend ops config directory.

$script:UltrasendOpsMarker = 'ultrasend-ops'
$script:UltrasendOpsSubdirs = @('cn', 'overseas', 'local', 'flutter', 'web', 'harmonyos')

function Write-UltrasendOpsHint {
    $hint = @'
请获取 ops 配置目录：

  # 方式 A：clone 到业务仓平级目录（推荐）
  git clone git@github.com:shrimpsend/public-ops.git ../ops    # 公开样例
  # 或维护者私有仓
  git clone git@github.com:shrimpsend/ops.git ../ops

  # 方式 B：自定义路径
  $env:ULTRASEND_OPS_DIR = 'D:\path\to\your-ops'

ops 根目录须包含 marker 文件 .ultrasend-ops（内容为 ultrasend-ops）
及至少一个配置子目录（cn/、overseas/、local/、flutter/、web/、harmonyos/）。
详见 ops/README.md
'@
    [Console]::Error.WriteLine($hint)
}

function Get-AbsolutePath {
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-UltrasendOpsDir {
    param([string] $Dir)

    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
        return $false
    }

    $marker = Join-Path $Dir '.ultrasend-ops'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        return $false
    }

    $firstLine = (Get-Content -LiteralPath $marker -TotalCount 1 -ErrorAction SilentlyContinue) -replace '\s', ''
    if ($firstLine -ne $script:UltrasendOpsMarker) {
        return $false
    }

    foreach ($sub in $script:UltrasendOpsSubdirs) {
        if (Test-Path -LiteralPath (Join-Path $Dir $sub) -PathType Container) {
            return $true
        }
    }

    return $false
}

function Assert-UltrasendOpsDir {
    param([string] $Dir)

    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
        [Console]::Error.WriteLine("错误: ops 目录不存在: $Dir")
        Write-UltrasendOpsHint
        exit 1
    }

    $marker = Join-Path $Dir '.ultrasend-ops'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        [Console]::Error.WriteLine("错误: 缺少 ops marker 文件: $marker")
        [Console]::Error.WriteLine('该目录不是有效的 ultrasend ops 配置仓。')
        Write-UltrasendOpsHint
        exit 1
    }

    if (-not (Test-UltrasendOpsDir $Dir)) {
        $firstLine = (Get-Content -LiteralPath $marker -TotalCount 1 -ErrorAction SilentlyContinue) -replace '\s', ''
        if ($firstLine -ne $script:UltrasendOpsMarker) {
            [Console]::Error.WriteLine("错误: ops marker 内容无效: $marker（期望首行为 ultrasend-ops）")
        }
        else {
            [Console]::Error.WriteLine("错误: ops 目录缺少预期子目录（cn/、overseas/、local/、flutter/、web/、harmonyos/ 至少其一）: $Dir")
        }
        Write-UltrasendOpsHint
        exit 1
    }
}

function Try-Resolve-UltrasendOpsDir {
    param([string] $Root)

    $candidate = $null
    if ($env:ULTRASEND_OPS_DIR) {
        $candidate = Get-AbsolutePath $env:ULTRASEND_OPS_DIR
    }
    elseif (Test-Path -LiteralPath (Join-Path $Root '..\ops') -PathType Container) {
        $candidate = Get-AbsolutePath (Join-Path $Root '..\ops')
    }
    else {
        return $null
    }

    if (Test-UltrasendOpsDir $candidate) {
        return $candidate
    }

    return $null
}

function Resolve-UltrasendOpsDir {
    param([string] $Root)

    $candidate = if ($env:ULTRASEND_OPS_DIR) {
        Get-AbsolutePath $env:ULTRASEND_OPS_DIR
    }
    else {
        Get-AbsolutePath (Join-Path $Root '..\ops')
    }

    Assert-UltrasendOpsDir $candidate
    return $candidate
}
