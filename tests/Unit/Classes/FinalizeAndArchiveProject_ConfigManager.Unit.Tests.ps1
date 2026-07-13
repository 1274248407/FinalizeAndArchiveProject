#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\ConfigManager.ps1')
}

Describe 'ConfigManager' {
    Context '实例化' {
        It '应成功创建 ConfigManager 实例' {
            $Manager = [ConfigManager]::new()
            $Manager | Should -Not -Be $null
        }
    }
}
