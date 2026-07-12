BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $modulePath -ChildPath 'Classes\BackupManager.ps1')
}

Describe 'BackupManager' {
    It 'Should create backup' {
        $tempDir = New-Item -ItemType Directory -Path (Join-Path -Path $env:TEMP -ChildPath 'test_backup') -Force
        $result = [BackupManager]::CreateBackup($tempDir.FullName)
        $result | Should -Be $true
        Remove-Item -Path $tempDir.FullName -Recurse -Force
        Remove-Item -Path ($tempDir.FullName + '_backup') -Recurse -Force -ErrorAction SilentlyContinue
    }
}