<#
.SYNOPSIS
    清理项目备份目录
.DESCRIPTION
    删除在项目同级目录下创建的 "${ProjectName}_backup" 备份文件夹。
    若备份目录不存在则静默跳过，不影响归档流程的正常执行。
.PARAMETER ProjectDir
    (string) 已归档的项目原路径
.EXAMPLE
    Remove-Backup -ProjectDir "D:\Projects\MyProject"
.OUTPUTS
    [bool] 清理成功或无需清理返回 $true，失败返回 $false
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Remove-Backup
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ProjectDir
    )

    # 解析并构造备份目录路径
    $ProjectPath = [System.IO.Path]::GetFullPath($ProjectDir)
    $ParentDir = [System.IO.Path]::GetDirectoryName($ProjectPath)
    $ProjectName = [System.IO.Path]::GetFileName($ProjectPath)
    $BackupDir = Join-Path -Path $ParentDir -ChildPath "${ProjectName}_backup"

    try
    {
        # 若备份目录存在则删除
        if (Test-Path -LiteralPath $BackupDir)
        {
            if ($PSCmdlet.ShouldProcess($BackupDir, '删除备份目录'))
            {
                Remove-Item -LiteralPath $BackupDir -Recurse -Force
                Write-Information "备份已清理: $BackupDir"
            }
        }
        return $true
    }
    catch
    {
        Write-Error "备份清理失败: $PSItem"
        return $false
    }
}
