#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Send-ToRecycleBin.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\BackupManager.ps1')
}

Describe 'BackupManager' {
    Context '正常备份' {
        It '应在指定路径创建完整备份（含顶层文件与嵌套子目录）' {
            # 使用 TestDrive 进行文件操作隔离
            $SourceDir = Join-Path -Path $TestDrive -ChildPath 'SourceProject'
            New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null

            # 在源目录中放入顶层文件和嵌套子目录文件，用于验证"完整备份"语义
            $TopFile = Join-Path -Path $SourceDir -ChildPath 'top.txt'
            'top content' | Out-File -LiteralPath $TopFile -Encoding UTF8 -NoNewline

            $SubDir = Join-Path -Path $SourceDir -ChildPath 'sub'
            New-Item -ItemType Directory -Path $SubDir -Force | Out-Null
            $NestedFile = Join-Path -Path $SubDir -ChildPath 'nested.txt'
            'nested content' | Out-File -LiteralPath $NestedFile -Encoding UTF8 -NoNewline

            $Result = [BackupManager]::CreateBackup($SourceDir)

            # 断言1：返回值应为 $true
            $Result | Should -Be $true

            # 断言2：备份目录应被创建
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'SourceProject_backup'
            $BackupDir | Should -Exist

            # 断言3：顶层文件应被复制且内容一致
            $BackupTopFile = Join-Path -Path $BackupDir -ChildPath 'top.txt'
            $BackupTopFile | Should -Exist
            (Get-Content -LiteralPath $BackupTopFile -Raw) | Should -Be 'top content'

            # 断言4：嵌套子目录文件应被递归复制且内容一致
            $BackupNestedFile = Join-Path -Path $BackupDir -ChildPath 'sub\nested.txt'
            $BackupNestedFile | Should -Exist
            (Get-Content -LiteralPath $BackupNestedFile -Raw) | Should -Be 'nested content'
        }

        It '应覆盖已存在的备份目录（旧文件被清理，新文件被写入）' {
            # Mock Send-ToRecycleBin：用永久删除替代回收站操作，避免污染系统回收站
            Mock Send-ToRecycleBin { Remove-Item -LiteralPath $Path -Recurse -Force }

            $SourceDir = Join-Path -Path $TestDrive -ChildPath 'SourceProject2'
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'SourceProject2_backup'
            New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

            # 在源目录中放入"新文件"标识，用于验证重新复制生效
            $NewMarker = Join-Path -Path $SourceDir -ChildPath 'new_marker.txt'
            'new' | Out-File -LiteralPath $NewMarker -Encoding UTF8 -NoNewline

            # 在已存在的备份目录中放入"旧文件"标识，用于验证清理生效
            $OldMarker = Join-Path -Path $BackupDir -ChildPath 'old_marker.txt'
            'old' | Out-File -LiteralPath $OldMarker -Encoding UTF8 -NoNewline

            $Result = [BackupManager]::CreateBackup($SourceDir)

            # 断言1：返回值应为 $true
            $Result | Should -Be $true

            # 断言2：旧备份中的陈旧文件应不再存在（证明 Send-ToRecycleBin 清理生效）
            $OldMarker | Should -Not -Exist

            # 断言3：源目录中的新文件应出现在备份目录中（证明 Copy-Item 重新复制生效）
            $BackupNewMarker = Join-Path -Path $BackupDir -ChildPath 'new_marker.txt'
            $BackupNewMarker | Should -Exist
            (Get-Content -LiteralPath $BackupNewMarker -Raw) | Should -Be 'new'

            # 断言4：应调用 Send-ToRecycleBin 清理旧备份目录（证明清理步骤被执行）
            Should -Invoke Send-ToRecycleBin -Times 1 -Exactly
        }

        It '应正确处理空源目录' {
            $SourceDir = Join-Path -Path $TestDrive -ChildPath 'EmptySource'
            New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null

            $Result = [BackupManager]::CreateBackup($SourceDir)

            # 断言1：空目录备份应成功
            $Result | Should -Be $true

            # 断言2：备份目录应被创建
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'EmptySource_backup'
            $BackupDir | Should -Exist

            # 断言3：备份目录应为空（无文件无子目录）
            (Get-ChildItem -LiteralPath $BackupDir -Force).Count | Should -Be 0
        }
    }

    Context '特殊路径字符' {
        It '应正确处理路径中的方括号特殊字符' {
            # 项目名包含 [test] 方括号，验证 -LiteralPath 生效
            # 使用 .NET 方法创建目录，避免 PowerShell 通配符解释
            $SourceDir = Join-Path -Path $TestDrive -ChildPath '2026-07-24_[test]'
            $null = [System.IO.Directory]::CreateDirectory($SourceDir)
            'content' | Out-File -LiteralPath (Join-Path $SourceDir 'file.txt') -NoNewline

            $Result = [BackupManager]::CreateBackup($SourceDir)

            # 断言1：方括号路径备份应成功
            $Result | Should -Be $true

            # 断言2：备份目录应被创建（用 -LiteralPath 避免通配符解释）
            $BackupDir = Join-Path -Path $TestDrive -ChildPath '2026-07-24_[test]_backup'
            Test-Path -LiteralPath $BackupDir | Should -Be $true

            # 断言3：文件应被复制且内容一致
            $BackupFile = Join-Path $BackupDir 'file.txt'
            Test-Path -LiteralPath $BackupFile | Should -Be $true
            (Get-Content -LiteralPath $BackupFile -Raw) | Should -Be 'content'
        }

        It '应正确处理路径中的中文字符' {
            $SourceDir = Join-Path -Path $TestDrive -ChildPath '测试专用文件夹'
            New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null
            '中文内容' | Out-File -LiteralPath (Join-Path $SourceDir '文件.txt') -NoNewline -Encoding UTF8

            $Result = [BackupManager]::CreateBackup($SourceDir)

            # 断言1：中文路径备份应成功
            $Result | Should -Be $true

            # 断言2：备份目录应被创建
            $BackupDir = Join-Path -Path $TestDrive -ChildPath '测试专用文件夹_backup'
            $BackupDir | Should -Exist

            # 断言3：中文文件名应被复制且内容一致
            $BackupFile = Join-Path $BackupDir '文件.txt'
            $BackupFile | Should -Exist
            (Get-Content -LiteralPath $BackupFile -Raw) | Should -Be '中文内容'
        }
    }

    Context '错误处理' {
        It '应在源目录不存在时返回 $false 且不抛出异常' {
            $NotExistDir = Join-Path -Path $TestDrive -ChildPath 'NotExist'

            $Result = [BackupManager]::CreateBackup($NotExistDir)

            # 断言：源目录不存在时应返回 $false（由 catch 块捕获 Copy-Item 异常）
            $Result | Should -Be $false
        }

        It '应在 Copy-Item 失败时返回 $false 且不抛出未捕获异常' {
            # Mock Copy-Item 模拟磁盘空间不足等失败场景
            Mock Copy-Item { throw '模拟磁盘空间不足' }

            $SourceDir = Join-Path -Path $TestDrive -ChildPath 'CopyFail'
            New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null
            'content' | Out-File -LiteralPath (Join-Path $SourceDir 'file.txt') -NoNewline

            $Result = [BackupManager]::CreateBackup($SourceDir)

            # 断言：Copy-Item 失败时应返回 $false（由 catch 块捕获异常）
            $Result | Should -Be $false
        }

        It '应在 Send-ToRecycleBin 抛异常时返回 $false 且不抛出未捕获异常' {
            # Mock Send-ToRecycleBin 模拟回收站操作彻底失败（含降级删除也失败）
            Mock Send-ToRecycleBin { throw '模拟回收站操作失败' }

            $SourceDir = Join-Path -Path $TestDrive -ChildPath 'RecycleFail'
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'RecycleFail_backup'
            New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

            $Result = [BackupManager]::CreateBackup($SourceDir)

            # 断言：Send-ToRecycleBin 失败时应返回 $false（由 catch 块捕获异常）
            $Result | Should -Be $false
        }

        It '应在传入空字符串时返回 $false 且不抛出异常' {
            # 空字符串会导致 GetFullPath 抛 ArgumentException
            $Result = [BackupManager]::CreateBackup('')

            # 断言：空字符串参数应返回 $false（由 catch 块捕获路径解析异常）
            $Result | Should -Be $false
        }
    }
}
