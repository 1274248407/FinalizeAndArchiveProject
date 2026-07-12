class ConfigManager {
    [hashtable] $_configCache
    [hashtable] $_validationCache

    ConfigManager() {
        $this._configCache = @{}
        $this._validationCache = @{}
    }

    [object] LoadConfigCached([string] $configFile) {
        $cacheKey = [System.IO.Path]::GetFullPath($configFile)

        if ($this._configCache.ContainsKey($cacheKey)) {
            $cachedEntry = $this._configCache[$cacheKey]
            $cachedTime = $cachedEntry.Time
            $config = $cachedEntry.Config
            $currentMtime = (Get-Item -Path $configFile -ErrorAction SilentlyContinue).LastWriteTimeUtc.Ticks
            if ($null -ne $currentMtime -and $currentMtime -le $cachedTime) {
                return $config
            }
        }

        $config = $this._LoadConfigInternal($configFile)
        if ($null -ne $config) {
            $currentMtime = (Get-Item -Path $configFile -ErrorAction SilentlyContinue).LastWriteTimeUtc.Ticks
            $this._configCache[$cacheKey] = @{
                Time   = $currentMtime
                Config = $config
            }
        }
        return $config
    }

    [object] _LoadConfigInternal([string] $configFile) {
        if (-not (Test-Path -Path $configFile -PathType Leaf)) {
            Write-Error "配置文件不存在: $configFile"
            return $null
        }

        try {
            $content = Get-Content -Path $configFile -Raw -Encoding UTF8
            return ConvertFrom-Toml -InputObject $content
        }
        catch {
            Write-Error "配置解析错误: $_"
            return $null
        }
    }
}