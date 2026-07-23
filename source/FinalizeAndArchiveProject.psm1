<#
.SYNOPSIS
    FinalizeAndArchiveProject 模块脚本
.DESCRIPTION
    高性能项目归档处理工具的核心模块。
    负责加载类定义、私有函数和公开函数，并导出公开接口。
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>

# 导入外部依赖模块
Import-Module PSToml -ErrorAction Stop

# 加载类定义文件（每个类独立文件，便于维护和测试）
$ClassFiles = @(
    'BackupManager',
    'ConfigManager',
    'OptimizedFileProcessor'
)

foreach ($ClassFile in $ClassFiles)
{
    $ClassPath = Join-Path -Path $PSScriptRoot -ChildPath "Classes\$ClassFile.ps1"
    if (Test-Path -Path $ClassPath)
    {
        . $ClassPath
    }
}

# 加载内部私有函数
$PrivateFunctions = @(
    'Test-PathExist',
    'Invoke-ArchiveProject',
    'Remove-Backup'

    foreach ($Function in $PrivateFunctions)
    {
        $FunctionPath = Join-Path -Path $PSScriptRoot -ChildPath "Private\$Function.ps1"
        if (Test-Path -Path $FunctionPath)
        {
            . $FunctionPath
        }
    }

    # 加载公开函数
    $PublicFunctions = @(
        'Start-FinalizeAndArchive',
        'Select-Project'
    )

    foreach ($Function in $PublicFunctions)
    {
        $FunctionPath = Join-Path -Path $PSScriptRoot -ChildPath "Public\$Function.ps1"
        if (Test-Path -Path $FunctionPath)
        {
            . $FunctionPath
        }
    }
    
    #

    # 导出公开函数 导出公开函数
    ExportceeMember -Function $PublicFunctionsExportceeMember -Function $PublicFunctions
