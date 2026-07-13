#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\BackupManager.ps1')
}

Describe 'BackupManager' {
    Context 'CreateBackup 方法' {
        It '应在指定路径创建完整备份' {
            # 使用 TestDrive 进行文件操作隔离
            $SourceDir = Join-Path -Path $TestDrive -ChildPath 'SourceProject'
            New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null

            $Result = [BackupManager]::CreateBackup($SourceDir)

            $Result | Should -Be $true
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'SourceProject_backup'
            $BackupDir | Should -Exist
        }

        It '应覆盖已存在的备份目录' {
            $SourceDir = Join-Path -Path $TestDrive -ChildPath 'SourceProject2'
            $BackupDir = Join-Path -Path $TestDrive -ChildPath 'SourceProject2_backup'
            New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

            $Result = [BackupManager]::CreateBackup($SourceDir)

            $Result | Should -Be $true
        }
    }
}
