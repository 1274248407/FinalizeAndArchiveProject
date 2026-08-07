#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\FileProcessor.ps1')
}

Describe 'FileProcessor' {
    Context '构造函数' {
        It '无参构造应设置合理的 MaxWorkers（1-64 之间）' {
            $Processor = [FileProcessor]::new()

            $Processor.MaxWorkers | Should -BeGreaterThan 0
            $Processor.MaxWorkers | Should -BeLessOrEqual 64
        }

        It '带参构造应将 MaxWorkers 设置为指定值' {
            $Processor = [FileProcessor]::new(8)

            $Processor.MaxWorkers | Should -Be 8
        }

        It '带参构造传入 0 应保留 0（调用方责任）' {
            $Processor = [FileProcessor]::new(0)

            $Processor.MaxWorkers | Should -Be 0
        }
    }

    Context 'GetMaxNumberFromFilenames 方法' {
        It '应在空数组时返回 0' {
            $Processor = [FileProcessor]::new()

            $Result = $Processor.GetMaxNumberFromFilenames(@())

            $Result | Should -Be 0
        }

        It '应在文件名无数字时返回 0' {
            $Processor = [FileProcessor]::new()

            $Result = $Processor.GetMaxNumberFromFilenames(@('readme.txt', 'changelog.md'))

            $Result | Should -Be 0
        }

        It '应正确提取单个文件名中的数字' {
            $Processor = [FileProcessor]::new()

            $Result = $Processor.GetMaxNumberFromFilenames(@('page001.jpg'))

            $Result | Should -Be 1
        }

        It '应在单个文件名含多个数字时返回最大值' {
            $Processor = [FileProcessor]::new()

            $Result = $Processor.GetMaxNumberFromFilenames(@('vol3_chapter15_page008.jpg'))

            $Result | Should -Be 15
        }

        It '应在多个文件名中返回全局最大值' {
            $Processor = [FileProcessor]::new()

            $Files = @('page001.jpg', 'page010.jpg', 'page003.jpg')
            $Result = $Processor.GetMaxNumberFromFilenames($Files)

            $Result | Should -Be 10
        }

        It '应在数字等于 1000000 时不触发快速路径（边界值）' {
            $Processor = [FileProcessor]::new()

            $Result = $Processor.GetMaxNumberFromFilenames(@('file1000000.txt'))

            $Result | Should -Be 1000000
        }

        It '应在数字超过 1000000 时触发快速路径立即返回' {
            $Processor = [FileProcessor]::new()

            # 第一个文件名含超大数字，应立即返回不再遍历后续文件
            $Files = @('file2000000.txt', 'file9999999.txt')
            $Result = $Processor.GetMaxNumberFromFilenames($Files)

            $Result | Should -Be 2000000
        }
    }

    Context 'ScanDirectory 方法' {
        It '应在目录不存在时返回空数组' {
            $Processor = [FileProcessor]::new()
            $NotExistDir = Join-Path -Path $TestDrive -ChildPath 'NotExist'

            $Result = $Processor.ScanDirectory($NotExistDir, $null)

            $Result | Should -Be @()
            $Result.Count | Should -Be 0
        }

        It '应在空目录时返回空数组' {
            $Processor = [FileProcessor]::new()
            $EmptyDir = Join-Path -Path $TestDrive -ChildPath 'Empty'
            New-Item -ItemType Directory -Path $EmptyDir -Force | Out-Null

            $Result = $Processor.ScanDirectory($EmptyDir, $null)

            $Result | Should -Be @()
            $Result.Count | Should -Be 0
        }

        It '应返回目录中的所有文件（无扩展名过滤）' {
            $Processor = [FileProcessor]::new()
            $Dir = Join-Path -Path $TestDrive -ChildPath 'Mixed'
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
            'a' | Out-File -LiteralPath (Join-Path $Dir 'a.txt') -NoNewline -Encoding UTF8
            'b' | Out-File -LiteralPath (Join-Path $Dir 'b.jpg') -NoNewline -Encoding UTF8

            $Result = $Processor.ScanDirectory($Dir, $null)

            @($Result.Name | Sort-Object) -join ',' | Should -Be 'a.txt,b.jpg'
        }

        It '应按扩展名过滤文件（大小写不敏感）' {
            $Processor = [FileProcessor]::new()
            $Dir = Join-Path -Path $TestDrive -ChildPath 'Filtered'
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
            'a' | Out-File -LiteralPath (Join-Path $Dir 'a.TXT') -NoNewline -Encoding UTF8
            'b' | Out-File -LiteralPath (Join-Path $Dir 'b.jpg') -NoNewline -Encoding UTF8
            'c' | Out-File -LiteralPath (Join-Path $Dir 'c.txt') -NoNewline -Encoding UTF8

            $Result = $Processor.ScanDirectory($Dir, @('.txt'))

            @($Result.Name | Sort-Object) -join ',' | Should -Be 'a.TXT,c.txt'
        }

        It '应正确处理路径中的方括号特殊字符' {
            $Processor = [FileProcessor]::new()
            $Dir = Join-Path -Path $TestDrive -ChildPath '2026-07-24_[test]'
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
            'content' | Out-File -LiteralPath (Join-Path $Dir 'page001.jpg') -NoNewline -Encoding UTF8

            $Result = $Processor.ScanDirectory($Dir, @('.jpg'))

            @($Result.Name) -join ',' | Should -Be 'page001.jpg'
        }
    }

    Context 'SortFiles 方法' {
        It '应在传入空数组时返回空数组' {
            $Processor = [FileProcessor]::new()

            $Result = $Processor.SortFiles(@())

            $Result | Should -Be @()
            $Result.Count | Should -Be 0
        }

        It '应在传入单个文件时原样返回' {
            $Processor = [FileProcessor]::new()
            $Dir = Join-Path -Path $TestDrive -ChildPath 'Single'
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
            $File = Get-Item (New-Item -ItemType File -Path (Join-Path $Dir 'only.txt') -Force)

            $Result = $Processor.SortFiles(@($File))

            $Result.Count | Should -Be 1
            $Result[0].Name | Should -Be 'only.txt'
        }

        It '应按自然顺序排序文件（file2 < file10）' {
            $Processor = [FileProcessor]::new()
            $Dir = Join-Path -Path $TestDrive -ChildPath 'NaturalSort'
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
            foreach ($Name in @('file10.txt', 'file2.txt', 'file1.txt'))
            {
                New-Item -ItemType File -Path (Join-Path $Dir $Name) -Force | Out-Null
            }
            $Files = Get-ChildItem -LiteralPath $Dir -File

            $Sorted = $Processor.SortFiles($Files)

            $Sorted[0].Name | Should -Be 'file1.txt'
            $Sorted[1].Name | Should -Be 'file2.txt'
            $Sorted[2].Name | Should -Be 'file10.txt'
        }
    }

    Context 'NaturalSortKey 方法' {
        It '应为包含数字的字符串生成排序键' {
            $Processor = [FileProcessor]::new()

            $Key = $Processor.NaturalSortKey('file123.txt')

            $Key | Should -Not -Be $null
            $Key | Should -Match 'file0000000123\.txt'
        }

        It '应按自然顺序正确排序文件列表' {
            $Processor = [FileProcessor]::new()
            $Files = @('file2.txt', 'file10.txt', 'file1.txt')

            $Sorted = $Files | Sort-Object { $Processor.NaturalSortKey($PSItem) }

            $Sorted[0] | Should -Be 'file1.txt'
            $Sorted[1] | Should -Be 'file2.txt'
            $Sorted[2] | Should -Be 'file10.txt'
        }

        It '应在空字符串时返回空字符串' {
            $Processor = [FileProcessor]::new()

            $Key = $Processor.NaturalSortKey('')

            $Key | Should -Be ''
        }

        It '应在无数字的字符串时返回原字符串' {
            $Processor = [FileProcessor]::new()

            $Key = $Processor.NaturalSortKey('readme.txt')

            $Key | Should -Be 'readme.txt'
        }

        It '应将多个数字段都补零对齐' {
            $Processor = [FileProcessor]::new()

            $Key = $Processor.NaturalSortKey('vol3_chapter15_page008.jpg')

            # 3 → 0000000003, 15 → 0000000015, 8 → 0000000008
            $Key | Should -Be 'vol0000000003_chapter0000000015_page0000000008.jpg'
        }

        It '应将超过 10 位的大数字补零后保持原长度' {
            $Processor = [FileProcessor]::new()

            # 12 位数字，PadLeft(10) 不会截断，返回原数字
            $Key = $Processor.NaturalSortKey('file123456789012.txt')

            $Key | Should -Be 'file123456789012.txt'
        }
    }
}
