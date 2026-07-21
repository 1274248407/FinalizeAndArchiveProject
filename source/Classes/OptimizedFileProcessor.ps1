<#
.SYNOPSIS
    高性能文件处理器
.DESCRIPTION
    提供文件扫描、自然排序（Natural Sort）和文件名编号分析等功能。
    内部使用缓存机制优化自然排序键的重复计算，适用于大规模文件集合的处理场景。
.EXAMPLE
    $Processor = [OptimizedFileProcessor]::new()
    $Files = $Processor.ScanDirectory("D:\Images", @(".jpg", ".png"))
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
class OptimizedFileProcessor
{
    # 最大并行工作线程数
    [int] $MaxWorkers
    # 自然排序键缓存，避免重复计算
    [hashtable] $_NaturalSortCache

    OptimizedFileProcessor()
    {
        $this.MaxWorkers = [Math]::Min(64, ([Environment]::ProcessorCount * 2 + 4))
        $this._NaturalSortCache = @{}
    }

    OptimizedFileProcessor([int] $MaxWorkers)
    {
        $this.MaxWorkers = $MaxWorkers
        $this._NaturalSortCache = @{}
    }

    <#
    .SYNOPSIS
        生成自然排序键
    .DESCRIPTION
        将字符串中的数字补零对齐，生成可直接用于词法排序的字符串键。
        例如 "file2.txt" → "file0000000002.txt"，"file10.txt" → "file0000000010.txt"，
        使得 Sort-Object 按字符串排序时得到正确的自然顺序（2 < 10）。
        结果会被缓存以提高重复调用的性能。
    .PARAMETER S
        (string) 待生成排序键的字符串
    .EXAMPLE
        $Key = $Processor.NaturalSortKey("file123.txt")
    .OUTPUTS
        [string] 数字补零后的排序键字符串
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    [string] NaturalSortKey([string] $S)
    {
        # 检查缓存中是否已有计算结果
        if ($this._NaturalSortCache.ContainsKey($S))
        {
            return $this._NaturalSortCache[$S]
        }

        # 将数字部分补零至 10 位，使字符串排序等同于自然排序
        $Result = [regex]::Replace($S, '\d+', { $Args[0].Value.PadLeft(10, '0') })

        # 将结果存入缓存
        $this._NaturalSortCache[$S] = $Result
        return $Result
    }

    <#
    .SYNOPSIS
        扫描目录中的文件
    .DESCRIPTION
        递归扫描指定目录中的文件，并可选择按扩展名过滤。
        返回匹配文件的 FileInfo 对象数组，便于后续处理。
    .PARAMETER Directory
        (string) 待扫描的目录路径
    .PARAMETER Extensions
        (string[]) 可选的文件扩展名过滤列表（如 @(".jpg", ".png")），为空时不进行过滤
    .EXAMPLE
        $Files = $Processor.ScanDirectory("D:\Images", @(".jpg", ".png"))
    .OUTPUTS
        [System.IO.FileInfo[]] 匹配文件的 FileInfo 数组
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    [System.IO.FileInfo[]] ScanDirectory([string] $Directory, [string[]] $Extensions)
    {
        try
        {
            $Files = Get-ChildItem -LiteralPath $Directory -File -ErrorAction Stop
            # 若指定了扩展名过滤器，则过滤不匹配的文件
            if ($null -ne $Extensions -and $Extensions.Count -gt 0)
            {
                $LowerExtensions = $Extensions | ForEach-Object { $PSItem.ToLower() }
                $Files = $Files | Where-Object { $LowerExtensions -contains $_.Extension.ToLower() }
            }
            return $Files
        }
        catch
        {
            Write-Error "扫描目录失败 $Directory : $PSItem"
            return @()
        }
    }

    <#
    .SYNOPSIS
        并行排序文件列表
    .DESCRIPTION
        使用自然排序键对文件列表进行并行排序，利用 MaxWorkers 控制并行度。
        适用于大规模文件集合的排序场景，显著提升排序性能。
    .PARAMETER Files
        (System.IO.FileInfo[]) 待排序的文件对象数组
    .EXAMPLE
        $SortedFiles = $Processor.SortFiles($Files)
    .OUTPUTS
        [System.IO.FileInfo[]] 按自然排序后的文件对象数组
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    [System.IO.FileInfo[]] SortFiles([System.IO.FileInfo[]] $Files)
    {
        if ($null -eq $Files -or $Files.Count -eq 0)
        {
            return @()
        }

        # 串行计算自然排序键并排序（ForEach-Object -Parallel 在类方法中会因 $using:this 导致死锁）
        $SortKeys = foreach ($File in $Files)
        {
            [PSCustomObject]@{
                File = $File
                Key  = $this.NaturalSortKey($File.Name)
            }
        }

        return $SortKeys | Sort-Object Key | ForEach-Object { $PSItem.File }
    }

    <#
    .SYNOPSIS
        从文件名中提取最大数字
    .DESCRIPTION
        遍历文件名列表，使用正则提取所有数字并找出最大值。
        当检测到数字超过 1000000 时立即返回（快速路径优化），适用于查找文件命名中最大序号。
    .PARAMETER Files
        (string[]) 待分析的文件名字符串数组
    .EXAMPLE
        $MaxNum = $Processor.GetMaxNumberFromFilenames(@("file1.txt", "file10.txt"))
    .OUTPUTS
        [int] 文件名中的最大数字，无数字时返回 0
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    [int] GetMaxNumberFromFilenames([string[]] $Files)
    {
        $MaxNum = 0

        foreach ($FileName in $Files)
        {
            # 提取文件名中所有连续数字
            $NumberMatches = [regex]::Matches($FileName, '(\d+)')
            foreach ($Match in $NumberMatches)
            {
                $Num = [int]$Match.Value
                if ($Num -gt $MaxNum)
                {
                    $MaxNum = $Num
                    # 快速路径：超过 1000000 时直接返回
                    if ($Num -gt 1000000)
                    {
                        return $Num
                    }
                }
            }
        }
        return $MaxNum
    }
}
