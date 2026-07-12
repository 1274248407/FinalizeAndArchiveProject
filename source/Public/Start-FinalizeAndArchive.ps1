function Start-FinalizeAndArchive {
    [CmdletBinding()]
    param (
        [string] $ConfigPath
    )

    $configManager = [ConfigManager]::new()
    $backupManager = [BackupManager]::new()
    $fileProcessor = [OptimizedFileProcessor]::new()

    if (-not $ConfigPath) {
        $searchPaths = @(
            '.\config.toml',
            "$HOME\.finalize_and_archive\config.toml",
            (Join-Path -Path $PSScriptRoot -ChildPath '..\config.toml')
        )

        foreach ($path in $searchPaths) {
            $fullPath = [System.IO.Path]::GetFullPath($path)
            if (Test-Path -Path $fullPath -PathType Leaf) {
                $ConfigPath = $fullPath
                break
            }
        }

        if (-not $ConfigPath) {
            Write-Error "未找到配置文件"
            return $false
        }
    }

    $config = $configManager.LoadConfigCached($ConfigPath)
    if ($null -eq $config) {
        Write-Error "配置加载失败"
        return $false
    }

    try {
        $activeDir = $config.paths.active_dir
        $archiveDir = $config.paths.archive_dir
        $warningImagePath = $config.paths.warning_image
        $imageExtensions = $config.settings.image_extensions | ForEach-Object { $_.ToLower() }
    }
    catch {
        Write-Error "配置键缺失: $_"
        return $false
    }

    if (-not (Test-PathExists -Paths @($activeDir, $archiveDir, $warningImagePath))) {
        return $false
    }

    $projectDir = Select-Project -ActiveDir $activeDir
    if (-not $projectDir) {
        return $false
    }

    if (-not [BackupManager]::CreateBackup($projectDir)) {
        $response = Read-Host "备份失败，是否继续? (y/n)"
        if ($response.ToLower() -ne 'y') {
            return $false
        }
    }

    $finalPagesPath = Join-Path -Path $projectDir -ChildPath '02_Preprocessing\result'
    if (-not (Test-Path -Path $finalPagesPath -PathType Container)) {
        Write-Error "完成页目录不存在: $finalPagesPath"
        return $false
    }

    $files = $fileProcessor.ScanDirectory($finalPagesPath, $imageExtensions)
    if ($files.Count -eq 0) {
        Write-Error "未找到图片文件"
        return $false
    }

    $files = $files | Sort-Object { $fileProcessor.NaturalSortKey($_.Name) }
    $fileNames = $files | ForEach-Object { $_.Name }

    $maxNum = $fileProcessor.GetMaxNumberFromFilenames($fileNames)
    $width = [Math]::Max($maxNum.ToString().Length, 3)

    for ($i = $files.Count - 1; $i -gt 0; $i--) {
        $oldPath = $files[$i].FullName
        $ext = $files[$i].Extension
        $newName = "{0:D$width}{1}" -f ($i + 2), $ext
        $newPath = Join-Path -Path $finalPagesPath -ChildPath $newName

        try {
            Rename-Item -Path $oldPath -NewName $newName -Force
        }
        catch {
            Write-Error "重命名失败 $oldPath -> $newName : $_"
            return $false
        }
    }

    try {
        $ext = [System.IO.Path]::GetExtension($warningImagePath)
        $warningTarget = Join-Path -Path $finalPagesPath -ChildPath ("{0:D$width}{1}" -f 2, $ext)
        Copy-Item -Path $warningImagePath -Destination $warningTarget -Force
        Write-Information "警告图片插入完成"
    }
    catch {
        Write-Error "复制警告图片失败: $_"
        return $false
    }

    $totalPages = $files.Count + 1

    $readmePath = Join-Path -Path $projectDir -ChildPath 'README.md'
    if (Test-Path -Path $readmePath -PathType Leaf) {
        try {
            $content = Get-Content -Path $readmePath -Raw -Encoding UTF8

            $items = @(
                '文件整理与分离',
                'OCR 处理与校对',
                'Inpainting 处理与修正',
                '文本翻译',
                '最终质量检查'
            )

            foreach ($item in $items) {
                $content = $content -replace '- \[ \] ' + [regex]::Escape($item), '- [X] ' + $item
            }

            $content = $content -replace '- \[\[ Xx\]\?\] 嵌字 \(完成至页 .*?\)', "- [X] 嵌字 (完成至页 $totalPages)"

            Set-Content -Path $readmePath -Value $content -Encoding UTF8 -NoNewline
            Write-Information "README更新完成"
        }
        catch {
            Write-Warning "README更新失败: $_"
        }
    }

    if (-not (Invoke-ArchiveProject -ProjectDir $projectDir -ArchiveDir $archiveDir)) {
        return $false
    }

    if (-not (Remove-Backup -ProjectDir $projectDir)) {
        Write-Warning "备份清理失败"
    }

    Write-Information "项目归档完成"
    return $true
}