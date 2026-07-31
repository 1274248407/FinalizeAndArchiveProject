<#
.SYNOPSIS
    执行文件准备流程
.DESCRIPTION
    扫描目录中的图片文件，按自然顺序排序，计算编号宽度，执行两阶段重命名（跳过第2位），插入警告图片。
    返回总页数（用于更新 README）。
.PARAMETER FinalPagesPath
    (string) 文件所在目录路径
.PARAMETER ImageExtensions
    (string[]) 图片扩展名过滤列表
.PARAMETER WarningImagePath
    (string) 警告图片路径
.EXAMPLE
    $TotalPages = Invoke-FilePreparation -FinalPagesPath $Dir -ImageExtensions @('.jpg','.png') -WarningImagePath $WarningImg
.INPUTS
    [string], [string[]], [string]
.OUTPUTS
    [int] 总页数（文件数 + 1），失败返回 0
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Invoke-FilePreparation
{
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FinalPagesPath,

        [Parameter(Mandatory = $true)]
        [string[]] $ImageExtensions,

        [Parameter(Mandatory = $true)]
        [string] $WarningImagePath
    )

    $FileProcessor = [OptimizedFileProcessor]::new()
    $Files = $FileProcessor.ScanDirectory($FinalPagesPath, $ImageExtensions)
    if ($Files.Count -eq 0)
    {
        Write-LogEntry -Level Warning -Message '未找到图片文件'
        return 0
    }

    $Files = $FileProcessor.SortFiles($Files)
    $FileNames = $Files | ForEach-Object { $PSItem.Name }
    $MaxNum = $FileProcessor.GetMaxNumberFromFilenames($FileNames)
    $Width = [Math]::Max($MaxNum.ToString().Length, 3)

    for ($i = $Files.Count - 1; $i -ge 0; $i--)
    {
        $OldPath = $Files[$i].FullName
        $Ext = $Files[$i].Extension
        $TmpName = "__tmp_{0:D$Width}{1}" -f $i, $Ext

        try
        {
            Rename-Item -LiteralPath $OldPath -NewName $TmpName -Force
        }
        catch
        {
            Write-LogEntry -Level Warning -Message "重命名失败 $OldPath -> $TmpName : $PSItem"
            return 0
        }
    }

    for ($i = $Files.Count - 1; $i -ge 0; $i--)
    {
        $Ext = $Files[$i].Extension
        $TmpName = "__tmp_{0:D$Width}{1}" -f $i, $Ext
        $TmpPath = Join-Path -Path $FinalPagesPath -ChildPath $TmpName
        $NewNum = if ($i -eq 0) { $i + 1 } else { $i + 2 }
        $NewName = "{0:D$Width}{1}" -f $NewNum, $Ext

        try
        {
            Rename-Item -LiteralPath $TmpPath -NewName $NewName -Force
        }
        catch
        {
            Write-LogEntry -Level Warning -Message "重命名失败 $TmpName -> $NewName : $PSItem"
            return 0
        }
    }

    try
    {
        $Ext = [System.IO.Path]::GetExtension($WarningImagePath)
        $WarningTarget = Join-Path -Path $FinalPagesPath -ChildPath ("{0:D$Width}{1}" -f 2, $Ext)
        Copy-Item -LiteralPath $WarningImagePath -Destination $WarningTarget -Force
        Write-LogEntry -Level Success -Message '警告图片插入完成'
    }
    catch
    {
        Write-LogEntry -Level Warning -Message "复制警告图片失败: $PSItem"
        return 0
    }

    return $Files.Count + 1
}
