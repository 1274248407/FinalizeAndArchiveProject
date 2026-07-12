BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\source'
    Import-Module $modulePath -Force
}

Describe 'Module Tests' {
    It 'Should import without errors' {
        { Import-Module $modulePath -Force } | Should -Not -Throw
    }

    It 'Should export expected functions' {
        $exportedFunctions = (Get-Module FinalizeAndArchiveProject).ExportedFunctions.Keys
        $exportedFunctions | Should -Contain 'Start-FinalizeAndArchive'
        $exportedFunctions | Should -Contain 'Select-Project'
    }

    It 'Should have valid manifest' {
        $manifest = Test-ModuleManifest -Path (Join-Path -Path $modulePath -ChildPath 'FinalizeAndArchiveProject.psd1')
        $manifest.Name | Should -Be 'FinalizeAndArchiveProject'
        $manifest.Version | Should -Be '0.1.0'
    }
}