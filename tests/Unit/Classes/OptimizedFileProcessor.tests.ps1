BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $modulePath -ChildPath 'Classes\OptimizedFileProcessor.ps1')
}

Describe 'OptimizedFileProcessor' {
    It 'Should create instance' {
        $processor = [OptimizedFileProcessor]::new()
        $processor | Should -Not -Be $null
    }

    It 'Should generate natural sort key' {
        $processor = [OptimizedFileProcessor]::new()
        $key = $processor.NaturalSortKey('file123.txt')
        $key | Should -Not -Be $null
    }

    It 'Should sort files naturally' {
        $processor = [OptimizedFileProcessor]::new()
        $files = @('file2.txt', 'file10.txt', 'file1.txt')
        $sorted = $files | Sort-Object { $processor.NaturalSortKey($_) }
        $sorted[0] | Should -Be 'file1.txt'
        $sorted[1] | Should -Be 'file2.txt'
        $sorted[2] | Should -Be 'file10.txt'
    }
}