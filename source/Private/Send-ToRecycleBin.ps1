<#
.SYNOPSIS
    将文件或目录移到 Windows 回收站
.DESCRIPTION
    使用 Microsoft.VisualBasic.FileIO.FileSystem 将指定路径移到回收站。
    若操作失败，静默降级为永久删除。
.PARAMETER Path
    (string) 要移到回收站的文件或目录路径
.EXAMPLE
    Send-ToRecycleBin -Path "D:\Projects\MyProject_backup"
.INPUTS
    [string]
.OUTPUTS
    [void]
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Send-ToRecycleBin
{
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    # 检查路径是否存在
    if (-not (Test-Path -LiteralPath $Path))
    {
        return
    }

    try
    {
        # 加载 Microsoft.VisualBasic 程序集
        Add-Type -AssemblyName 'Microsoft.VisualBasic'

        # 根据路径类型选择删除方法
        if (Test-Path -LiteralPath $Path -PathType Container)
        {
            # 目录：使用 DeleteDirectory 移到回收站
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
        }
        else
        {
            # 文件：使用 DeleteFile 移到回收站
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
        }
    }
    catch
    {
        # 回收站操作失败时降级为永久删除
        Write-LogEntry -Level Warning -Message "回收站操作失败，降级为永久删除: $Path"
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}
