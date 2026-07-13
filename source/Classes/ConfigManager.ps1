<#
.SYNOPSIS
    配置文件管理器
.DESCRIPTION
    负责加载、解析和缓存 TOML 格式的配置文件。
    通过文件修改时间判断缓存是否有效，避免重复读取磁盘，提升高频访问场景下的性能。
.EXAMPLE
    $Manager = [ConfigManager]::new()
    $Config = $Manager.LoadConfigCached("D:\Config\config.toml")
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
class ConfigManager
{
    # 配置文件缓存，键为文件路径，值为包含时间戳和配置数据的哈希表
    [hashtable] $_ConfigCache
    # 参数验证结果缓存
    [hashtable] $_ValidationCache

    ConfigManager()
    {
        $this._ConfigCache = @{}
        $this._ValidationCache = @{}
    }

    <#
    .SYNOPSIS
        加载并缓存配置文件
    .DESCRIPTION
        通过文件最后修改时间判断缓存是否过期。若缓存有效则直接返回，否则重新加载文件。
        适用于需要频繁读取配置且有缓存需求的场景。
    .PARAMETER ConfigFile
        (string) 配置文件的完整路径
    .EXAMPLE
        $Config = $ConfigManager.LoadConfigCached("D:\Config\config.toml")
    .OUTPUTS
        [object] 配置对象，加载失败返回 $null
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    [object] LoadConfigCached([string] $ConfigFile)
    {
        # 计算缓存键（规范化路径）
        $CacheKey = [System.IO.Path]::GetFullPath($ConfigFile)

        # 检查缓存是否存在且未过期
        if ($this._ConfigCache.ContainsKey($CacheKey))
        {
            $CachedEntry = $this._ConfigCache[$CacheKey]
            $CachedTime = $CachedEntry.Time
            $Config = $CachedEntry.Config
            # 获取文件最新修改时间并比较
            $CurrentMtime = (Get-Item -Path $ConfigFile -ErrorAction SilentlyContinue).LastWriteTimeUtc.Ticks
            if ($null -ne $CurrentMtime -and $CurrentMtime -le $CachedTime)
            {
                return $Config
            }
        }

        # 缓存未命中或已过期，重新加载配置文件
        $Config = $this._LoadConfigInternal($ConfigFile)
        if ($null -ne $Config)
        {
            $CurrentMtime = (Get-Item -Path $ConfigFile -ErrorAction SilentlyContinue).LastWriteTimeUtc.Ticks
            $this._ConfigCache[$CacheKey] = @{
                Time   = $CurrentMtime
                Config = $Config
            }
        }
        return $Config
    }

    <#
    .SYNOPSIS
        内部方法：从磁盘加载并解析配置文件
    .DESCRIPTION
        检查文件是否存在，读取其原始内容并使用 PSToml 模块解析为 PowerShell 对象。
    .PARAMETER ConfigFile
        (string) 配置文件的完整路径
    .EXAMPLE
        $Config = $this._LoadConfigInternal("D:\Config\config.toml")
    .OUTPUTS
        [object] TOML 解析后的配置对象，文件不存在或解析失败返回 $null
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    [object] _LoadConfigInternal([string] $ConfigFile)
    {
        # 检查配置文件是否存在
        if (-not (Test-Path -Path $ConfigFile -PathType Leaf))
        {
            Write-Error "配置文件不存在: $ConfigFile"
            return $null
        }

        try
        {
            # 读取并解析 TOML 配置文件
            $Content = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
            return ConvertFrom-Toml -InputObject $Content
        }
        catch
        {
            Write-Error "配置解析错误: $PSItem"
            return $null
        }
    }
}
