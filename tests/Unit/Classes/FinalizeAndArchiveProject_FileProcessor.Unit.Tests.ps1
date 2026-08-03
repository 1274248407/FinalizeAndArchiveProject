#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\FileProcessor.ps1')
}

Describe 'FileProcessor' {
    Context '实例化' {
        It '应成功创建 FileProcessor 实例' {
            $Processor = [FileProcessor]::new()
            $Processor | Should -Not -Be $null
        }
    }

    Context 'NaturalSortKey 方法' {
        It '应为包含数字的字符串生成排序键' {
            $Processor = [FileProcessor]::new()
            $Key = $Processor.NaturalSortKey('file123.txt')
            $Key | Should -Not -Be $null
        }

        It '应按自然顺序正确排序文件列表' {
            $Processor = [FileProcessor]::new()
            $Files = @('file2.txt', 'file10.txt', 'file1.txt')
            $Sorted = $Files | Sort-Object { $Processor.NaturalSortKey($PSItem) }
            $Sorted[0] | Should -Be 'file1.txt'
            $Sorted[1] | Should -Be 'file2.txt'
            $Sorted[2] | Should -Be 'file10.txt'
        }
    }
}
