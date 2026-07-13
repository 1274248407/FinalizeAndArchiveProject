<#
.SYNOPSIS
    项目备份管理器
.DESCRIPTION
    负责为项目目录创建完整备份，包含备份路径自动生成、已存在备份的覆盖处理等功能。
    备份目录将创建在原项目同级目录下，以 "${ProjectName}_backup" 命名。
.EXAMPLE
    [BackupManager]::CreateBackup("D:\Projects\MyProject")
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
class BackupManager {
    <#
    .SYNOPSIS
        创建项目目录的完整备份
    .DESCRIPTION
        将指定的项目目录完整复制到同级目录下的 "${ProjectName}_backup" 文件夹。
        若目标备份目录已存在，则先删除再重新创建，确保备份为最新状态。
    .PARAMETER ProjectDir
        (string) 待备份的项目目录路径
    .EXAMPLE
        [BackupManager]::CreateBackup("D:\Projects\MyProject")
    .OUTPUTS
        [bool] 备份成功返回 $true，失败返回 $false
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    static [bool] CreateBackup([string] $ProjectDir) {
        # 解析项目路径的各个部分
        $ProjectPath = [System.IO.Path]::GetFullPath($ProjectDir)
        $ParentDir = [System.IO.Path]::GetDirectoryName($ProjectPath)
        $ProjectName = [System.IO.Path]::GetFileName($ProjectPath)
        # 构造备份目录路径
        $BackupDir = Join-Path -Path $ParentDir -ChildPath "${ProjectName}_backup"

        try {
            # 若备份目录已存在，先清理再重新复制
            if (Test-Path -Path $BackupDir) {
                Remove-Item -Path $BackupDir -Recurse -Force
            }
            Copy-Item -Path $ProjectPath -Destination $BackupDir -Recurse -Force
            Write-Information "备份创建成功: $BackupDir"
            return $true
        }
        catch {
            Write-Error "备份失败: $PSItem"
            return $false
        }
    }
}
