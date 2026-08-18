<#
.SYNOPSIS
解析并验证配置文件
.DESCRIPTION
按优先级搜索配置文件，加载并验证必要的配置项。
返回包含 ActiveDir、ArchiveDir、WarningImagePath、ImageExtensions 的配置对象。
.PARAMETER ConfigPath
(string) 配置文件路径。若未指定，自动搜索当前目录、用户目录和模块目录。
.EXAMPLE
$Config = Resolve-Config -ConfigPath 'D:\Config\config.toml'
.INPUTS
[string]
.OUTPUTS
[PSCustomObject] 成功返回配置对象，失败返回 $null
.NOTES
Author: lucas_gold
Website: https://github.com/1274248407
#>
function Resolve-Config
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [string] $ConfigPath
    )

    if (-not $ConfigPath)
    {
        $SearchPaths = @(
            '.\config.toml',
            "$HOME\.finalize_and_archive\config.toml",
            (Join-Path -Path $PSScriptRoot -ChildPath '..\config.toml')
        )

        foreach ($Path in $SearchPaths)
        {
            $FullPath = [System.IO.Path]::GetFullPath($Path)
            if (Test-Path -LiteralPath $FullPath -PathType Leaf)
            {
                $ConfigPath = $FullPath
                break
            }
        }

        if (-not $ConfigPath)
        {
            Write-LogEntry -Level Warning -Message '未找到配置文件'
            return $null
        }
    }

    $Config = [ConfigManager]::LoadConfig($ConfigPath)
    if ($null -eq $Config)
    {
        Write-LogEntry -Level Warning -Message '配置加载失败'
        return $null
    }

    try
    {
        # 引用 TOML 配置节：使用索引器（而非点号）访问 OrderedDictionary 键
        # 点号访问不存在的键在 StrictMode Latest 下抛 PropertyNotFoundException（即使是 OrderedDictionary 自带动态键访问）
        # 索引器访问不存在的键始终短路返回 $null，StrictMode 安全
        [object]$PathsSection = $Config['paths']
        [object]$SettingsSection = $Config['settings']

        # 三元运算符（pwsh7 新语法）：对应节/字段缺失时返回空值或空数组，StrictMode 下不抛异常
        # 注意：不使用 ?. 空条件访问 — PowerShell 解析器会把 $var?. 解析为变量名含 `?`（与自动变量 $? 冲突）
        return [PSCustomObject]@{
            ActiveDir        = ($null -ne $PathsSection) ? $PathsSection['active_dir'] : $null
            ArchiveDir       = ($null -ne $PathsSection) ? $PathsSection['archive_dir'] : $null
            WarningImagePath = ($null -ne $PathsSection) ? $PathsSection['warning_image'] : $null
            ImageExtensions  = (($null -ne $SettingsSection -and $null -ne $SettingsSection['image_extensions']) ?
                @($SettingsSection['image_extensions'] | ForEach-Object { $PSItem.ToLower() }) : @())
        }
    }
    catch
    {
        Write-LogEntry -Level Warning -Message "配置键缺失: $PSItem"
        return $null
    }
}
