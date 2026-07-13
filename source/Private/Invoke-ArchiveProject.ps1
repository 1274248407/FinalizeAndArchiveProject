<#
.SYNOPSIS
    将项目目录归档到目标位置
.DESCRIPTION
    将指定的项目目录移动到归档目录中，完成物理归档操作。
    归档失败时返回 $false 以便调用方进行错误处理。
.PARAMETER ProjectDir
    (string) 待归档的项目目录路径
.PARAMETER ArchiveDir
    (string) 目标归档根目录路径
.EXAMPLE
    Invoke-ArchiveProject -ProjectDir "D:\Projects\MyProject" -ArchiveDir "D:\Archive"
.OUTPUTS
    [bool] 归档成功返回 $true，失败返回 $false
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Invoke-ArchiveProject {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ProjectDir,
        [Parameter(Mandatory = $true)]
        [string] $ArchiveDir
    )

    try {
        # 提取项目名称并构造目标路径
        $ProjectName = [System.IO.Path]::GetFileName($ProjectDir)
        $Destination = Join-Path -Path $ArchiveDir -ChildPath $ProjectName

        Move-Item -Path $ProjectDir -Destination $Destination -Force
        Write-Information "项目已归档: $ArchiveDir"
        return $true
    }
    catch {
        Write-Error "归档失败: $PSItem"
        return $false
    }
}
