<#
.SYNOPSIS
    验证多个路径是否存在
.DESCRIPTION
    检查指定的路径数组中的每一个路径是否存在。
    任一路径不存在即返回 $false 并输出错误信息，适用于执行前的环境预检。
.PARAMETER Paths
    (string[]) 待检查的路径数组
.EXAMPLE
    Test-PathExist -Paths @("D:\Dir1", "D:\Dir2", "D:\file.txt")
.OUTPUTS
    [bool] 所有路径均存在返回 $true，任一缺失返回 $false
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Test-PathExist
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string[]] $Paths
    )

    # 遍历所有路径进行检查
    foreach ($CheckPath in $Paths)
    {
        if (-not (Test-Path -LiteralPath $CheckPath))
        {
            Write-Error "路径不存在: $CheckPath"
            return $false
        }
    }
    return $true
}
