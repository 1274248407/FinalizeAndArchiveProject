class OptimizedFileProcessor {
    [int] $MaxWorkers
    [hashtable] $_naturalSortCache

    OptimizedFileProcessor() {
        $this.MaxWorkers = [Math]::Min(32, ([Environment]::ProcessorCount + 4))
        $this._naturalSortCache = @{}
    }

    OptimizedFileProcessor([int] $maxWorkers) {
        $this.MaxWorkers = $maxWorkers
        $this._naturalSortCache = @{}
    }

    [object[]] NaturalSortKey([string] $s) {
        if ($this._naturalSortCache.ContainsKey($s)) {
            return $this._naturalSortCache[$s]
        }

        $parts = [regex]::Split($s, '(\d+)')
        $result = @()

        foreach ($part in $parts) {
            if ([string]::IsNullOrEmpty($part)) {
                continue
            }
            if ($part -match '^\d+$') {
                $result += [int]$part
            }
            else {
                $result += $part.ToLower()
            }
        }

        $this._naturalSortCache[$s] = $result
        return $result
    }

    [System.IO.FileInfo[]] ScanDirectory([string] $directory, [string[]] $extensions) {
        try {
            $files = Get-ChildItem -Path $directory -File -ErrorAction Stop
            if ($null -ne $extensions -and $extensions.Count -gt 0) {
                $lowerExtensions = $extensions | ForEach-Object { $_.ToLower() }
                $files = $files | Where-Object { $lowerExtensions -contains $_.Extension.ToLower() }
            }
            return $files
        }
        catch {
            Write-Error "扫描目录失败 $directory : $_"
            return @()
        }
    }

    [int] GetMaxNumberFromFilenames([string[]] $files) {
        $maxNum = 0

        foreach ($fileName in $files) {
            $matches = [regex]::Matches($fileName, '(\d+)')
            foreach ($match in $matches) {
                $num = [int]$match.Value
                if ($num -gt $maxNum) {
                    $maxNum = $num
                    if ($num -gt 1000000) {
                        return $num
                    }
                }
            }
        }
        return $maxNum
    }
}

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

class BackupManager {
    static [bool] CreateBackup([string] $projectDir) {
        $projectPath = [System.IO.Path]::GetFullPath($projectDir)
        $parentDir = [System.IO.Path]::GetDirectoryName($projectPath)
        $projectName = [System.IO.Path]::GetFileName($projectPath)
        $backupDir = Join-Path -Path $parentDir -ChildPath "${projectName}_backup"

        try {
            if (Test-Path -Path $backupDir) {
                Remove-Item -Path $backupDir -Recurse -Force
            }
            Copy-Item -Path $projectPath -Destination $backupDir -Recurse -Force
            Write-Information "备份创建成功: $backupDir"
            return $true
        }
        catch {
            Write-Error "备份失败: $_"
            return $false
        }
    }
}

$privateFunctions = @(
    'Test-PathExists',
    'Invoke-ArchiveProject',
    'Remove-Backup'
)

foreach ($function in $privateFunctions) {
    $functionPath = Join-Path -Path $PSScriptRoot -ChildPath "Private\$function.ps1"
    if (Test-Path -Path $functionPath) {
        . $functionPath
    }
}

$publicFunctions = @(
    'Start-FinalizeAndArchive',
    'Select-Project'
)

foreach ($function in $publicFunctions) {
    $functionPath = Join-Path -Path $PSScriptRoot -ChildPath "Public\$function.ps1"
    if (Test-Path -Path $functionPath) {
        . $functionPath
    }
}

Export-ModuleMember -Function $publicFunctions