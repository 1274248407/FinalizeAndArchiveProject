<#
.SYNOPSIS
执行项目归档处理
.DESCRIPTION
对指定项目执行完整的归档流程：加载配置 → 选择项目 → 创建备份 → 准备文件 →
更新 README 进度 → 归档到目标目录 → 清理备份。
支持自动搜索配置文件路径，并涵盖完整的错误处理和回退逻辑。
.PARAMETER ConfigPath
(string) 配置文件路径。若未指定，将按优先级自动搜索当前目录、用户目录和模块目录。
.EXAMPLE
Start-FinalizeAndArchive -ConfigPath 'D:\Config\config.toml'
.EXAMPLE
Start-FinalizeAndArchive
.INPUTS
[string]
.OUTPUTS
[bool] 归档成功返回 $true，任一环节失败返回 $false
.NOTES
Author: lucas_gold
Website: https://github.com/1274248407
#>
function Start-FinalizeAndArchive
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([bool])]
    param (
        [string] $ConfigPath
    )

    $Config = Resolve-Config -ConfigPath $ConfigPath
    if (-not $Config) { return $false }

    if (-not (Test-PathExist -Paths @($Config.ActiveDir, $Config.ArchiveDir, $Config.WarningImagePath)))
    {
        return $false
    }

    $ProjectDir = Select-Project -ActiveDir $Config.ActiveDir
    if (-not $ProjectDir) { return $false }

    if (-not $PSCmdlet.ShouldProcess($ProjectDir, '执行项目归档')) { return $true }

    if (-not [BackupManager]::CreateBackup($ProjectDir))
    {
        $Response = Read-Host '备份失败，是否继续? (y/n)'
        if ($Response.ToLower() -ne 'y') { return $false }
    }

    $FinalPagesPath = Join-Path -Path $ProjectDir -ChildPath '02_Preprocessing\result'
    if (-not (Test-Path -LiteralPath $FinalPagesPath -PathType Container))
    {
        Write-LogEntry -Level Warning -Message "完成页目录不存在: $FinalPagesPath"
        return $false
    }

    $TotalPages = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions $Config.ImageExtensions -WarningImagePath $Config.WarningImagePath
    if ($TotalPages -eq 0) { return $false }

    Update-ReadmeProgress -ProjectDir $ProjectDir -TotalPages $TotalPages

    if (-not (Invoke-ArchiveProject -ProjectDir $ProjectDir -ArchiveDir $Config.ArchiveDir))
    {
        return $false
    }

    if (-not (Remove-Backup -ProjectDir $ProjectDir))
    {
        Write-LogEntry -Level Warning -Message '备份清理失败'
    }

    Write-LogEntry -Level Success -Message '项目归档完成'
    return $true
}
