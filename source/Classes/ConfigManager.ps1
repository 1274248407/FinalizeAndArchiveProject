<#
.SYNOPSIS
    配置文件管理器
.DESCRIPTION
    负责从磁盘加载和解析 TOML 格式的配置文件。
    所有方法均为静态方法，无需创建实例即可调用。
.EXAMPLE
    $Config = [ConfigManager]::LoadConfig("D:\Config\config.toml")
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
class ConfigManager
{
    <#
    .SYNOPSIS
        从磁盘加载并解析配置文件
    .DESCRIPTION
        检查文件是否存在，读取其原始内容并使用 PSToml 模块解析为 PowerShell 对象。
    .PARAMETER ConfigFile
        (string) 配置文件的完整路径
    .EXAMPLE
        $Config = [ConfigManager]::LoadConfig("D:\Config\config.toml")
    .OUTPUTS
        [object] TOML 解析后的配置对象，文件不存在或解析失败返回 $null
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    static [object] LoadConfig([string] $ConfigFile)
    {
        # 检查配置文件是否存在
        if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf))
        {
            Write-LogEntry -Level Warning -Message "配置文件不存在: $ConfigFile"
            return $null
        }

        try
        {
            # 读取并解析 TOML 配置文件（使用 -LiteralPath 支持方括号等特殊字符路径）
            $Content = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8
            return ConvertFrom-Toml -InputObject $Content
        }
        catch
        {
            Write-LogEntry -Level Warning -Message "配置解析错误: $PSItem"
            return $null
        }
    }
}
