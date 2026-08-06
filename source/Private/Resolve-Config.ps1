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
        return [PSCustomObject]@{
            ActiveDir        = $Config.paths.active_dir
            ArchiveDir       = $Config.paths.archive_dir
            WarningImagePath = $Config.paths.warning_image
            ImageExtensions  = $Config.settings.image_extensions | ForEach-Object { $PSItem.ToLower() }
        }
    }
    catch
    {
        Write-LogEntry -Level Warning -Message "配置键缺失: $PSItem"
        return $null
    }
}
