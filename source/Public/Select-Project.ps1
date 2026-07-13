<#
.SYNOPSIS
    交互式选择待处理项目
.DESCRIPTION
    扫描活动项目目录，筛选符合日期前缀命名规范（yyyy-MM-dd_*）的项目，
    并以列表形式让用户通过编号交互选择。提供输入验证和错误处理。
.PARAMETER ActiveDir
    (string) 活动项目所在的根目录路径
.EXAMPLE
    $ProjectDir = Select-Project -ActiveDir "D:\Projects\Active"
.INPUTS
    [string]
.OUTPUTS
    [string] 用户选择的项目完整路径，取消或无项目时返回 $null
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Select-Project
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ActiveDir
    )

    # 匹配日期前缀格式：yyyy-MM-dd_
    $Pattern = '^\d{4}-\d{2}-\d{2}_'

    # 扫描并筛选符合条件的项目目录
    $Projects = @()
    try
    {
        $Entries = Get-ChildItem -Path $ActiveDir -Directory -ErrorAction Stop
        foreach ($Entry in $Entries)
        {
            if ($Entry.Name -match $Pattern)
            {
                $Projects += $Entry.FullName
            }
        }
    }
    catch
    {
        Write-Error "扫描项目目录失败: $PSItem"
        return $null
    }

    # 无项目时直接返回
    if ($Projects.Count -eq 0)
    {
        Write-Warning '未找到项目'
        return $null
    }

    # 显示项目列表供用户选择
    Write-Information '请选择项目:'
    for ($i = 0; $i -lt $Projects.Count; $i++)
    {
        $ProjectName = [System.IO.Path]::GetFileName($Projects[$i])
        Write-Information ('{0}. {1}' -f ($i + 1), $ProjectName)
    }

    # 循环读取用户输入，直到获取有效编号
    while ($true)
    {
        try
        {
            $Choice = Read-Host '输入编号'
            $Index = [int]$Choice - 1

            if ($Index -ge 0 -and $Index -lt $Projects.Count)
            {
                return $Projects[$Index]
            }
            Write-Warning '编号超出范围'
        }
        catch
        {
            Write-Warning '请输入有效数字'
        }
    }
}
