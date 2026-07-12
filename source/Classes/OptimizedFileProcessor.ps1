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