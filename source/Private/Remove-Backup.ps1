function Remove-Backup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ProjectDir
    )

    $projectPath = [System.IO.Path]::GetFullPath($ProjectDir)
    $parentDir = [System.IO.Path]::GetDirectoryName($projectPath)
    $projectName = [System.IO.Path]::GetFileName($projectPath)
    $backupDir = Join-Path -Path $parentDir -ChildPath "${projectName}_backup"

    try {
        if (Test-Path -Path $backupDir) {
            Remove-Item -Path $backupDir -Recurse -Force
            Write-Information "备份已清理: $backupDir"
        }
        return $true
    }
    catch {
        Write-Error "备份清理失败: $_"
        return $false
    }
}