<#
.SYNOPSIS
    执行文件准备流程
.DESCRIPTION
    扫描目录中的图片文件，按自然顺序排序，计算编号宽度，执行两阶段重命名（跳过第2位），插入警告图片。
    返回总页数（用于更新 README）。
    入口处对路径和扩展名进行防御性校验与规范化：去除尾部反斜杠、补全扩展名前导点、拒绝空扩展名列表和无扩展名警告图。
.PARAMETER FinalPagesPath
    (string) 文件所在目录路径
.PARAMETER ImageExtensions
    (string[]) 图片扩展名过滤列表，支持带点（'.jpg'）或不带点（'jpg'）格式，内部自动规范化为带点
.PARAMETER WarningImagePath
    (string) 警告图片路径，必须包含文件扩展名
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
        [AllowEmptyString()]
        [string] $FinalPagesPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]] $ImageExtensions,

        [Parameter(Mandatory = $true)]
        [string] $WarningImagePath
    )

    # 规范化路径：去除尾部反斜杠，避免空目录名问题
    try
    {
        $FinalPagesPath = [System.IO.Path]::GetFullPath($FinalPagesPath).TrimEnd('\', '/')
        $WarningImagePath = [System.IO.Path]::GetFullPath($WarningImagePath).TrimEnd('\', '/')
    }
    catch
    {
        Write-LogEntry -Level Warning -Message "路径规范化失败: $PSItem"
        return 0
    }

    # 校验扩展名列表非空，空列表会跳过过滤导致非图片文件被处理
    if ($ImageExtensions.Count -eq 0)
    {
        Write-LogEntry -Level Warning -Message '图片扩展名列表为空'
        return 0
    }

    # 规范化扩展名：确保以点开头（'jpg' → '.jpg'）
    $ImageExtensions = @($ImageExtensions | ForEach-Object { $PSItem -notmatch '^\.' ? ".$PSItem" : $PSItem })

    # 校验警告图片路径包含扩展名，无扩展名时目标文件名缺少后缀
    if ([string]::IsNullOrEmpty([System.IO.Path]::GetExtension($WarningImagePath)))
    {
        Write-LogEntry -Level Warning -Message '警告图片路径缺少扩展名'
        return 0
    }

    # 校验警告图片路径必须是文件（拒绝目录），避免 Copy-Item 把整个目录当警告图复制
    if ((Test-Path -LiteralPath $WarningImagePath) -and -not (Test-Path -LiteralPath $WarningImagePath -PathType Leaf))
    {
        Write-LogEntry -Level Warning -Message '警告图片路径指向目录而非文件'
        return 0
    }

    $FileProcessor = [FileProcessor]::new()
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
            Rename-Item -LiteralPath $OldPath -NewName $TmpName -Force -ErrorAction Stop
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
        # 首个文件从 1 开始编号，其余递增 2 以保持原序号偏移
        $NewNum = $i -eq 0 ? $i + 1 : $i + 2
        $NewName = "{0:D$Width}{1}" -f $NewNum, $Ext

        try
        {
            Rename-Item -LiteralPath $TmpPath -NewName $NewName -Force -ErrorAction Stop
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
        Copy-Item -LiteralPath $WarningImagePath -Destination $WarningTarget -Force -ErrorAction Stop
        Write-LogEntry -Level Success -Message '警告图片插入完成'
    }
    catch
    {
        Write-LogEntry -Level Warning -Message "复制警告图片失败: $PSItem"
        return 0
    }

    return $Files.Count + 1
}
