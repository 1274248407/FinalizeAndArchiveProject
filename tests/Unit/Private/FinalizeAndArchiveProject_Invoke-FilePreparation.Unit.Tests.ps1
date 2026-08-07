#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\FileProcessor.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Invoke-FilePreparation.ps1')
}

Describe 'Invoke-FilePreparation' {
    Context '参数校验' {
        It '应将 FinalPagesPath 标记为 Mandatory 参数' {
            Get-Command Invoke-FilePreparation | Should -HaveParameter FinalPagesPath -Mandatory
        }
        It '应将 ImageExtensions 标记为 Mandatory 参数' {
            Get-Command Invoke-FilePreparation | Should -HaveParameter ImageExtensions -Mandatory
        }
        It '应将 WarningImagePath 标记为 Mandatory 参数' {
            Get-Command Invoke-FilePreparation | Should -HaveParameter WarningImagePath -Mandatory
        }
    }

    Context '未找到图片文件（扫描为空返回 0）' {
        It '应在目录无匹配图片时输出 "未找到图片文件" Warning 并返回 0' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'EmptyDir'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            # 放一个非图片文件
            'data' | Out-File -LiteralPath (Join-Path -Path $FinalPagesPath -ChildPath 'data.txt') -NoNewline -Encoding UTF8

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg', '.png') -WarningImagePath 'a.jpg'

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '未找到图片文件' } -Times 1 -Exactly
        }
    }

    Context '真实两阶段重命名 + 警告图片插入（3 张图片）' {
        BeforeEach {
            Mock Write-LogEntry { }

            # 构造测试目录
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'FilePrepReal'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null

            # 警告图片
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [byte[]]$FakeImg = 0x01, 0x02
            [System.IO.File]::WriteAllBytes($WarningImg, $FakeImg)

            # 3 张图片
            @('1.jpg', '2.jpg', '3.jpg') | ForEach-Object {
                $File = Join-Path -Path $FinalPagesPath -ChildPath $PSItem
                [System.IO.File]::WriteAllBytes($File, $FakeImg)
            }
        }

        It '应重命名 3 张图片：结果文件为 001.jpg, 003.jpg, 004.jpg, 002.webp（总页数 4）' {
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'FilePrepReal'
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'

            $TotalPages = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $TotalPages | Should -Be 4

            # 验证所有最终文件名
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp', '003.jpg', '004.jpg')

            # 警告图片在目标目录下的 002.webp 应与源相同大小/内容
            (Test-Path -LiteralPath (Join-Path -Path $FinalPagesPath -ChildPath '002.webp')) | Should -Be $true
        }

        It '应在第一阶段 Rename-Item 抛异常时输出 Warning 并返回 0（不半残）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'FilePrepReal'
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'

            # 让 Rename-Item 在第一次调用抛异常
            Mock Rename-Item { throw 'rename disk error' }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*重命名失败*' } -Times 1 -Exactly
        }
    }

    Context 'Copy-Item 警告图片失败（catch 分支）' {
        It '应在 Copy-Item 警告图片时抛异常返回 0 并输出 Warning 日志' {
            Mock Write-LogEntry { }

            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'FilePrepWarnFail'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn_missing.webp'  # 故意不存在

            # 构造两张图片
            @('1.png', '2.png') | ForEach-Object {
                $File = Join-Path -Path $FinalPagesPath -ChildPath $PSItem
                [System.IO.File]::WriteAllBytes($File, [byte[]](0x01, 0x02))
            }

            Mock Rename-Item { }  # 重命名 mock 通过（否则就卡在前面）
            Mock Copy-Item { throw 'copy failure' }  # 复制警告图强制失败

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.png') -WarningImagePath $WarningImg

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*复制警告图片失败*' } -Times 1 -Exactly
        }
    }
}
