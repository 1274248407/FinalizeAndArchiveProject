<#
.SYNOPSIS
    执行项目归档处理
.DESCRIPTION
    对指定项目执行完整的归档流程：加载配置 → 选择项目 → 创建备份 → 调整文件编号 →
    插入警告图片 → 更新 README 进度 → 归档到目标目录 → 清理备份。
    支持自动搜索配置文件路径，并涵盖完整的错误处理和回退逻辑。
.PARAMETER ConfigPath
    (string) 配置文件路径。若未指定，将按优先级自动搜索当前目录、用户目录和模块目录。
.EXAMPLE
    Start-FinalizeAndArchive -ConfigPath "D:\Config\config.toml"
.EXAMPLE
    Start-FinalizeAndArchive
.INPUTS
    [string]
.OUTPUTS
    [bool] 归档成功返回 $true，任一环节失败返回 $false
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Start-FinalizeAndArchive {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [string] $ConfigPath
    )

    # 初始化各管理器实例
    $ConfigManager = [ConfigManager]::new()
    $BackupManager = [BackupManager]::new()
    $FileProcessor = [OptimizedFileProcessor]::new()

    # 若未指定配置文件，按优先级自动搜索
    if (-not $ConfigPath) {
        $SearchPaths = @(
            '.\config.toml',
            "$HOME\.finalize_and_archive\config.toml",
            (Join-Path -Path $PSScriptRoot -ChildPath '..\config.toml')
        )

        foreach ($Path in $SearchPaths) {
            $FullPath = [System.IO.Path]::GetFullPath($Path)
            if (Test-Path -Path $FullPath -PathType Leaf) {
                $ConfigPath = $FullPath
                break
            }
        }

        # 未找到任何配置文件则返回错误
        if (-not $ConfigPath) {
            Write-Error "未找到配置文件"
            return $false
        }
    }

    # 加载配置
    $Config = $ConfigManager.LoadConfigCached($ConfigPath)
    if ($null -eq $Config) {
        Write-Error "配置加载失败"
        return $false
    }

    # 提取并验证配置键
    try {
        $ActiveDir = $Config.paths.active_dir
        $ArchiveDir = $Config.paths.archive_dir
        $WarningImagePath = $Config.paths.warning_image
        $ImageExtensions = $Config.paths.image_extensions | ForEach-Object { $PSItem.ToLower() }
    }
    catch {
        Write-Error "配置键缺失: $PSItem"
        return $false
    }

    # 验证关键路径是否存在
    if (-not (Test-PathExists -Paths @($ActiveDir, $ArchiveDir, $WarningImagePath))) {
        return $false
    }

    # 选择待处理项目
    $ProjectDir = Select-Project -ActiveDir $ActiveDir
    if (-not $ProjectDir) {
        return $false
    }

    # 创建项目备份
    if (-not [BackupManager]::CreateBackup($ProjectDir)) {
        $Response = Read-Host "备份失败，是否继续? (y/n)"
        if ($Response.ToLower() -ne 'y') {
            return $false
        }
    }

    # 构建完成页目录路径
    $FinalPagesPath = Join-Path -Path $ProjectDir -ChildPath '02_Preprocessing\result'
    if (-not (Test-Path -Path $FinalPagesPath -PathType Container)) {
        Write-Error "完成页目录不存在: $FinalPagesPath"
        return $false
    }

    # 扫描图片文件并按自然排序
    $Files = $FileProcessor.ScanDirectory($FinalPagesPath, $ImageExtensions)
    if ($Files.Count -eq 0) {
        Write-Error "未找到图片文件"
        return $false
    }

    $Files = $Files | Sort-Object { $FileProcessor.NaturalSortKey($PSItem.Name) }
    $FileNames = $Files | ForEach-Object { $PSItem.Name }

    # 计算编号宽度（取最大数字位数和 3 中较大值）
    $MaxNum = $FileProcessor.GetMaxNumberFromFilenames($FileNames)
    $Width = [Math]::Max($MaxNum.ToString().Length, 3)

    # 从后往前重命名文件，腾出第 2 位给警告图片
    for ($i = $Files.Count - 1; $i -gt 0; $i--) {
        $OldPath = $Files[$i].FullName
        $Ext = $Files[$i].Extension
        $NewName = "{0:D$Width}{1}" -f ($i + 2), $Ext
        $NewPath = Join-Path -Path $FinalPagesPath -ChildPath $NewName

        try {
            Rename-Item -Path $OldPath -NewName $NewName -Force
        }
        catch {
            Write-Error "重命名失败 $OldPath -> $NewName : $PSItem"
            return $false
        }
    }

    # 将警告图片插入第 2 位
    try {
        $Ext = [System.IO.Path]::GetExtension($WarningImagePath)
        $WarningTarget = Join-Path -Path $FinalPagesPath -ChildPath ("{0:D$Width}{1}" -f 2, $Ext)
        Copy-Item -Path $WarningImagePath -Destination $WarningTarget -Force
        Write-Information "警告图片插入完成"
    }
    catch {
        Write-Error "复制警告图片失败: $PSItem"
        return $false
    }

    # 计算总页数（原始文件数 + 插入的警告图片）
    $TotalPages = $Files.Count + 1

    # 更新 README 中的进度标记
    $ReadmePath = Join-Path -Path $ProjectDir -ChildPath 'README.md'
    if (Test-Path -Path $ReadmePath -PathType Leaf) {
        try {
            $Content = Get-Content -Path $ReadmePath -Raw -Encoding UTF8

            # 待完成任务列表
            $Items = @(
                '文件整理与分离',
                'OCR 处理与校对',
                'Inpainting 处理与修正',
                '文本翻译',
                '最终质量检查'
            )

            # 将所有待办项标记为已完成
            foreach ($Item in $Items) {
                $Content = $Content -replace '- \[ \] ' + [regex]::Escape($Item), '- [X] ' + $Item
            }

            # 更新嵌字进度
            $Content = $Content -replace '- \[\[ Xx\]\?\] 嵌字 \(完成至页 .*?\)', "- [X] 嵌字 (完成至页 $TotalPages)"

            Set-Content -Path $ReadmePath -Value $Content -Encoding UTF8 -NoNewline
            Write-Information "README更新完成"
        }
        catch {
            Write-Warning "README更新失败: $PSItem"
        }
    }

    # 执行归档操作
    if (-not (Invoke-ArchiveProject -ProjectDir $ProjectDir -ArchiveDir $ArchiveDir)) {
        return $false
    }

    # 清理备份
    if (-not (Remove-Backup -ProjectDir $ProjectDir)) {
        Write-Warning "备份清理失败"
    }

    Write-Information "项目归档完成"
    return $true
}
