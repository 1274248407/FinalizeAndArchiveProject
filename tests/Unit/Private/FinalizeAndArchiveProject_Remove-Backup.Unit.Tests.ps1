#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Send-ToRecycleBin.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Remove-Backup.ps1')
}

Describe 'Remove-Backup' {
    Context '参数校验' {
        It '应将 ProjectDir 标记为 Mandatory 参数' {
            Get-Command Remove-Backup | Should -HaveParameter ProjectDir -Mandatory
        }
    }

    Context '备份目录不存在（无需清理）' {
        It '应在备份目录不存在时返回 $true（静默跳过）' {
            Mock Write-LogEntry { }
            Mock Send-ToRecycleBin { }
            $FakeProjectDir = Join-Path -Path $TestDrive -ChildPath 'NoBackup'
            New-Item -ItemType Directory -Path $FakeProjectDir -Force | Out-Null

            $Result = Remove-Backup -ProjectDir $FakeProjectDir -Confirm:$false

            $Result | Should -Be $true
            Should -Not -Invoke Send-ToRecycleBin -Scope It
        }
    }

    Context '备份目录存在并清理' {
        It '应调用 Send-ToRecycleBin 清理存在的备份目录并返回 $true' {
            Mock Write-LogEntry { }
            Mock Send-ToRecycleBin { } -Verifiable

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'MyProject'
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'MyProject_backup'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

            $Result = Remove-Backup -ProjectDir $ProjectDir -Confirm:$false

            $Result | Should -Be $true
            Should -Invoke Send-ToRecycleBin -Scope It -ParameterFilter { $Path -eq $BackupDir } -Times 1 -Exactly
        }

        It '应使用 -LiteralPath 支持方括号路径的备份目录' {
            Mock Write-LogEntry { }
            Mock Send-ToRecycleBin { }

            $BracketProjectName = '2026_[test]'
            $ProjectDir = Join-Path -Path $TestDrive -ChildPath $BracketProjectName
            $BackupDir = Join-Path -Path $TestDrive -ChildPath ($BracketProjectName + '_backup')
            [System.IO.Directory]::CreateDirectory($ProjectDir) | Out-Null
            [System.IO.Directory]::CreateDirectory($BackupDir) | Out-Null

            $Result = Remove-Backup -ProjectDir $ProjectDir -Confirm:$false

            $Result | Should -Be $true
            Should -Invoke Send-ToRecycleBin -Scope It -ParameterFilter { $Path -eq $BackupDir } -Times 1 -Exactly
        }

        It '应通过 GetFullPath 规范化路径末尾反斜杠后正确拼接 _backup' {
            Mock Write-LogEntry { }
            Mock Send-ToRecycleBin { }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'TrimTest'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'TrimTest_backup'
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

            # 调试：验证备份目录存在
            (Test-Path -LiteralPath $BackupDir) | Should -Be $true

            # 传入路径末尾带多余反斜杠，GetFullPath 应规范化它
            # 由于 ConfirmImpact='High'，即使传 -Confirm:$false 也应通过
            $Result = Remove-Backup -ProjectDir ($ProjectDir + '\') -Confirm:$false

            $Result | Should -Be $true
            Should -Invoke Send-ToRecycleBin -Scope It -ParameterFilter { $Path -like '*TrimTest_backup' } -Times 1 -Exactly
        }
    }

    Context '异常处理（catch 分支）' {
        It '应在 Send-ToRecycleBin 抛异常时输出 Warning 并返回 $false' {
            Mock Write-LogEntry { }
            Mock Send-ToRecycleBin { throw 'disk full' }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'ErrProject'
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'ErrProject_backup'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

            $Result = Remove-Backup -ProjectDir $ProjectDir -Confirm:$false

            $Result | Should -Be $false
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*备份清理失败*' } -Times 1 -Exactly
        }
    }
}
