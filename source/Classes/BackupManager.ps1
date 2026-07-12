class BackupManager {
    static [bool] CreateBackup([string] $projectDir) {
        $projectPath = [System.IO.Path]::GetFullPath($projectDir)
        $parentDir = [System.IO.Path]::GetDirectoryName($projectPath)
        $projectName = [System.IO.Path]::GetFileName($projectPath)
        $backupDir = Join-Path -Path $parentDir -ChildPath "${projectName}_backup"

        try {
            if (Test-Path -Path $backupDir) {
                Remove-Item -Path $backupDir -Recurse -Force
            }
            Copy-Item -Path $projectPath -Destination $backupDir -Recurse -Force
            Write-Information "备份创建成功: $backupDir"
            return $true
        }
        catch {
            Write-Error "备份失败: $_"
            return $false
        }
    }
}