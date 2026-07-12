BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $modulePath -ChildPath 'Classes\ConfigManager.ps1')
}

Describe 'ConfigManager' {
    It 'Should create instance' {
        $manager = [ConfigManager]::new()
        $manager | Should -Not -Be $null
    }
}