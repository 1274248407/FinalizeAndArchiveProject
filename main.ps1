<#
.SYNOPSIS
    FinalizeAndArchiveProject - 项目归档处理工具入口脚本
.DESCRIPTION
    便捷启动脚本，自动加载模块并执行项目归档流程。
    支持通过 -ConfigPath 参数指定配置文件路径，未指定时将按优先级自动搜索。
.PARAMETER ConfigPath
    (string) 配置文件路径，可选。未指定时自动按以下优先级搜索：
    1. 当前工作目录下的 config.toml
    2. $HOME\.finalize_and_archive\config.toml
    3. 模块目录上级的 config.toml
.EXAMPLE
    .\main.ps1
.EXAMPLE
    .\main.ps1 -ConfigPath "D:\Documents\config.toml"
.INPUTS
    [string]
.OUTPUTS
    [int] 成功返回 0，失败返回 1
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
param (
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

# 定位模块根目录并导入模块
$ModuleRoot = $PSScriptRoot
$ModuleSource = Join-Path -Path $ModuleRoot -ChildPath 'source'

try
{
    Import-Module (Join-Path $ModuleSource 'FinalizeAndArchiveProject.psm1') -Force -ErrorAction Stop
}
catch
{
    Write-Error "模块导入失败: $PSItem"
    exit 1
}

# 执行归档流程
$Result = Start-FinalizeAndArchive -ConfigPath $ConfigPath

if (-not $Result)
{
    # 归档失败，播放失败提示音
    Invoke-NotificationSound -SoundType Error
    exit 1
}

# 归档成功，播放成功提示音ationSound -SoundType Error
Invoke-NotificationSound -SoundType Success
