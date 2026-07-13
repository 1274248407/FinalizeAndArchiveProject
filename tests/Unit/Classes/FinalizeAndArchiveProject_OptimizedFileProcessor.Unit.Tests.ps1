#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\OptimizedFileProcessor.ps1')
}

Describe 'OptimizedFileProcessor' {
    Context '实例化' {
        It '应成功创建 OptimizedFileProcessor 实例' {
            $Processor = [OptimizedFileProcessor]::new()
            $Processor | Should -Not -Be $null
        }
    }

    Context 'NaturalSortKey 方法' {
        It '应为包含数字的字符串生成排序键' {
            $Processor = [OptimizedFileProcessor]::new()
            $Key = $Processor.NaturalSortKey('file123.txt')
            $Key | Should -Not -Be $null
        }

        It '应按自然顺序正确排序文件列表' {
            $Processor = [OptimizedFileProcessor]::new()
            $Files = @('file2.txt', 'file10.txt', 'file1.txt')
            $Sorted = $Files | Sort-Object { $Processor.NaturalSortKey($PSItem) }
            $Sorted[0] | Should -Be 'file1.txt'
            $Sorted[1] | Should -Be 'file2.txt'
            $Sorted[2] | Should -Be 'file10.txt'
        }
    }
}
