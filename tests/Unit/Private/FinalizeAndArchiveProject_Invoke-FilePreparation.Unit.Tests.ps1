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
        It '应在 ImageExtensions 为空数组时返回 0 并输出 Warning' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'EmptyExt'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @() -WarningImagePath 'a.jpg'

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '图片扩展名列表为空' } -Times 1 -Exactly
        }
        It '应在 WarningImagePath 无扩展名时返回 0 并输出 Warning' {
            Mock Write-LogEntry { }
            # 注意：无扩展名校验在 ScanDirectory 之前 early return，故不需要真实目录/文件
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'NoExtWarn'

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath 'warn_no_ext'

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '警告图片路径缺少扩展名' } -Times 1 -Exactly
        }
    }

    Context '路径规范化异常' {
        It '应在 FinalPagesPath 为空字符串时返回 0 并输出"路径规范化失败"' {
            Mock Write-LogEntry { }

            $Result = Invoke-FilePreparation -FinalPagesPath '' -ImageExtensions @('.jpg') -WarningImagePath 'a.jpg'

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*路径规范化失败*' } -Times 1 -Exactly
        }
        It '应在 FinalPagesPath 含非法路径字符时返回 0 并输出"路径规范化失败"' {
            Mock Write-LogEntry { }

            # 内嵌 NUL 字符触发路径非法异常
            $BadPath = 'bad{0}path' -f [char]0x0000
            $Result = Invoke-FilePreparation -FinalPagesPath $BadPath -ImageExtensions @('.jpg') -WarningImagePath 'a.jpg'

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*路径规范化失败*' } -Times 1 -Exactly
        }
    }

    Context 'WarningImagePath 指向目录' {
        It '应在 WarningImagePath 指向目录时返回 0 并输出 Warning' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'WarnIsDir'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            # 创建一个带扩展名的目录
            $WarningDir = Join-Path -Path $TestDrive -ChildPath 'warning.jpg'
            New-Item -ItemType Directory -Path $WarningDir -Force | Out-Null
            # 放图片确保不是"未找到图片"导致的 return 0
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '1.jpg'), [byte[]](0x01))

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningDir

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '警告图片路径指向目录而非文件' } -Times 1 -Exactly
        }
    }

    Context '扩展名规范化与大小写' {
        It '应将无点扩展名规范化为带点格式后正确匹配' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'DotNorm'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '1.jpg'), [byte[]](0x01, 0x02))

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 2
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp')
        }
        It '应正确匹配大写扩展名 ImageExtensions（大小写不敏感）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'CaseInsensitive'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '1.jpg'), [byte[]](0x01, 0x02))

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.JPG') -WarningImagePath $WarningImg

            $Result | Should -Be 2
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp')
        }
    }

    Context '路径规范化' {
        It '应正确处理 FinalPagesPath 尾部反斜杠' {
            Mock Write-LogEntry { }
            # 故意构造带尾部反斜杠的路径
            $FinalPagesPath = (Join-Path -Path $TestDrive -ChildPath 'TrailingSlash') + '\'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            @('1.jpg', '2.jpg', '3.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), [byte[]](0x01, 0x02))
            }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 4
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp', '003.jpg', '004.jpg')
        }
    }

    Context 'FinalPagesPath 指向文件而非目录' {
        It '应在 FinalPagesPath 指向文件时返回 0 并输出 Warning（文件路径被 Get-ChildItem 当作容器处理）' {
            Mock Write-LogEntry { }
            # 创建一个真实文件作为误传的 FinalPagesPath
            # Get-ChildItem -LiteralPath <文件> -File 在 Windows 上不抛异常，直接返回该文件
            # 因此如果文件扩展名不匹配 ImageExtensions，最终走"未找到图片文件"路径
            $FakePath = Join-Path -Path $TestDrive -ChildPath 'file_not_dir.txt'
            'not a dir' | Out-File -LiteralPath $FakePath -NoNewline -Encoding UTF8

            $Result = Invoke-FilePreparation -FinalPagesPath $FakePath -ImageExtensions @('.jpg') -WarningImagePath 'a.jpg'

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '未找到图片文件' } -Times 1 -Exactly
        }
    }

    Context '未找到图片文件' {
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
        It '应在 FinalPagesPath 不存在时输出"扫描目录失败"+"未找到图片文件"两条 Warning 并返回 0' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'NonExistentDir'

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg', '.png') -WarningImagePath 'a.jpg'

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*扫描目录失败*' } -Times 1 -Exactly
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '未找到图片文件' } -Times 1 -Exactly
        }
    }

    Context '基本重命名流程' {
        It '应正确处理单张图片：返回 2，最终文件为 001.jpg + 002.webp' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'SingleFile'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '1.jpg'), [byte[]](0x01, 0x02))

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 2
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp')
        }

        It '应在文件名无数字时使用 Width 下限 3（cover.jpg → 001.jpg, back.jpg → 003.jpg）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'NoDigits'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            # 文件名不含任何数字，GetMaxNumberFromFilenames 返回 0，Width 下限兜底为 3
            @('cover.jpg', 'back.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), [byte[]](0x01, 0x02))
            }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 3
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp', '003.jpg')
        }

        It '应按自然序（非字典序）排序：1, 2, 3, 10 而非 1, 10, 2, 3（混合扩展名）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'NaturalSort'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            # 故意打乱创建顺序：先 10，再 2，验证自然排序
            @('1.jpg', '10.jpg', '2.jpg', '3.png') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), [byte[]](0x01, 0x02))
            }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg', '.png') -WarningImagePath $WarningImg

            $Result | Should -Be 5
            # 自然排序后：1.jpg(i=0→001), 2.jpg(i=1→003), 3.png(i=2→004), 10.jpg(i=3→005) + 警告 002.webp
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp', '003.jpg', '004.png', '005.jpg')
        }

        It '应正确处理文件名中含超大数字（>1000000 快速路径，Width=7）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'QuickPath'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            # 文件名含 1000001，触发 GetMaxNumberFromFilenames 快速路径，Width = 7
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '1000001.jpg'), [byte[]](0x01, 0x02))

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 2
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('0000001.jpg', '0000002.webp')
        }

        It '应正确处理文件名含方括号和空格（[1].jpg, [10].jpg, page 2.png）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'SpecialChars'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            # 方括号 + 空格 + 数字，验证 -LiteralPath 和自然排序的正确性
            @('[1].jpg', '[10].jpg', 'page 2.png') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), [byte[]](0x01, 0x02))
            }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg', '.png') -WarningImagePath $WarningImg

            $Result | Should -Be 4
            # 自然排序：[1].jpg(i=0→001), [10].jpg(i=1→003), page 2.png(i=2→004) + 警告 002.webp
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp', '003.jpg', '004.png')
        }

        It '应忽略目录中的子目录，仅处理文件' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'WithSubdir'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            @('1.jpg', '2.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), [byte[]](0x01, 0x02))
            }
            # 创建子目录（不应被 ScanDirectory 返回）
            New-Item -ItemType Directory -Path (Join-Path -Path $FinalPagesPath -ChildPath 'SubDir') -Force | Out-Null

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 3
            # 子目录仍然存在且未被重命名
            (Test-Path -LiteralPath (Join-Path -Path $FinalPagesPath -ChildPath 'SubDir')) | Should -Be $true
            # 最终文件列表（仅文件）应精确匹配
            $Files = @(Get-ChildItem -LiteralPath $FinalPagesPath -File -Force)
            @($Files.Name | Sort-Object) | Should -Be @('001.jpg', '002.webp', '003.jpg')
        }

        It '应在 MaxNum Length=2 时兜底到 Width=3（10~99 范围不退化）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'WidthLen2'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            # MaxNum=99, Length=2, Max(2,3)=3 → 3 位宽度，不应退化为 2 位
            @('1.jpg', '99.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), [byte[]](0x01, 0x02))
            }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 3
            # 验证 3 位宽度：001（不是 1）、003（不是 3）、002.webp（警告图位置不变）
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp', '003.jpg')
        }

        It '应在 MaxNum Length=4 时使用 Width=4（覆盖下限 3）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'WidthLen4'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [System.IO.File]::WriteAllBytes($WarningImg, [byte[]](0x01, 0x02))
            # MaxNum=1234, Length=4, Max(4,3)=4 → 4 位宽度
            @('1.jpg', '1234.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), [byte[]](0x01, 0x02))
            }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 3
            # 验证 4 位宽度：0001、0003、0002.webp
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('0001.jpg', '0002.webp', '0003.jpg')
        }
    }

    Context '内容完整性验证' {
        It '应保留每张图片的原始内容（唯一字节映射：1.jpg→001, 2.jpg→003, 3.jpg→004）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'ContentIntegrity'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'

            # 每张图片写入唯一标识字节，验证重命名不改变内容且映射正确
            [byte[]]$Bytes1 = 0xAA
            [byte[]]$Bytes2 = 0xBB
            [byte[]]$Bytes3 = 0xCC
            [byte[]]$WarnBytes = 0xDD, 0xEE

            [System.IO.File]::WriteAllBytes($WarningImg, $WarnBytes)
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '1.jpg'), $Bytes1)
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '2.jpg'), $Bytes2)
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '3.jpg'), $Bytes3)

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 4
            # 验证重命名映射：1.jpg→001.jpg, 2.jpg→003.jpg, 3.jpg→004.jpg
            ([System.IO.File]::ReadAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '001.jpg')) -join ',') | Should -Be ($Bytes1 -join ',')
            ([System.IO.File]::ReadAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '003.jpg')) -join ',') | Should -Be ($Bytes2 -join ',')
            ([System.IO.File]::ReadAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '004.jpg')) -join ',') | Should -Be ($Bytes3 -join ',')
            # 验证警告图片内容完整性
            ([System.IO.File]::ReadAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '002.webp')) -join ',') | Should -Be ($WarnBytes -join ',')
        }

        It '应正确处理警告图与原图同扩展名（002.jpg 是警告图而非原图）' {
            Mock Write-LogEntry { }
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'SameExt'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.jpg'

            # 警告图与原图同为 .jpg，验证 002.jpg 是警告图而非原图（跳过 002 逻辑验证）
            [byte[]]$WarnBytes = 0xDD, 0xEE
            [byte[]]$Bytes1 = 0xAA
            [byte[]]$Bytes2 = 0xBB
            [System.IO.File]::WriteAllBytes($WarningImg, $WarnBytes)
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '1.jpg'), $Bytes1)
            [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '2.jpg'), $Bytes2)

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 3
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.jpg', '003.jpg')
            # 002.jpg 内容应与警告图一致，而非原图 2.jpg
            ([System.IO.File]::ReadAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '002.jpg')) -join ',') | Should -Be ($WarnBytes -join ',')
            # 003.jpg 内容应与原图 2.jpg 一致
            ([System.IO.File]::ReadAllBytes((Join-Path -Path $FinalPagesPath -ChildPath '003.jpg')) -join ',') | Should -Be ($Bytes2 -join ',')
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

        It '应重命名 3 张图片：结果文件为 001.jpg, 003.jpg, 004.jpg, 002.webp（总页数 4）并输出 Success 日志' {
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'FilePrepReal'
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'

            $TotalPages = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $TotalPages | Should -Be 4
            # 验证所有最终文件名
            @(Get-ChildItem -LiteralPath $FinalPagesPath -Force).Name | Sort-Object | Should -Be @('001.jpg', '002.webp', '003.jpg', '004.jpg')
            # 警告图片在目标目录下存在
            (Test-Path -LiteralPath (Join-Path -Path $FinalPagesPath -ChildPath '002.webp')) | Should -Be $true
            # 验证 Success 日志
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Success' -and $Message -eq '警告图片插入完成' } -Times 1 -Exactly
        }
    }

    Context '第一阶段重命名失败' {
        It '应在第一阶段 Rename-Item 抛异常时输出 Warning 并返回 0（不半残：原始文件不变）' {
            Mock Write-LogEntry { }

            # 使用独立目录，避免与其他测试的 TestDrive 残留冲突
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'FirstStageFail'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [byte[]]$FakeImg = 0x01, 0x02
            [System.IO.File]::WriteAllBytes($WarningImg, $FakeImg)
            @('1.jpg', '2.jpg', '3.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), $FakeImg)
            }

            # 让 Rename-Item 在每次调用都抛异常
            Mock Rename-Item { throw 'rename disk error' }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*重命名失败*' } -Times 1 -Exactly
            # 半残状态断言：不应出现临时命名或最终命名格式的文件
            $TmpFiles = @(Get-ChildItem -LiteralPath $FinalPagesPath -Force | Where-Object { $PSItem.Name -match '^__tmp_' })
            $TmpFiles.Count | Should -Be 0
            $FinalNamedFiles = @(Get-ChildItem -LiteralPath $FinalPagesPath -Force | Where-Object { $PSItem.Name -match '^\d{3}\.' })
            $FinalNamedFiles.Count | Should -Be 0
            # 原始文件应仍然存在
            @(Get-ChildItem -LiteralPath $FinalPagesPath -File -Force).Name | Sort-Object | Should -Be @('1.jpg', '2.jpg', '3.jpg')
        }
    }

    Context '第二阶段重命名失败' {
        It '应在第二阶段 Rename-Item 抛异常时输出 Warning 并返回 0（半残状态：仅 __tmp_ 文件）' {
            Mock Write-LogEntry { }

            # 使用独立目录
            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'SecondStageFail'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [byte[]]$FakeImg = 0x01, 0x02
            [System.IO.File]::WriteAllBytes($WarningImg, $FakeImg)
            @('1.jpg', '2.jpg', '3.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), $FakeImg)
            }

            # 仅对第二阶段调用（NewName 不以 __tmp_ 开头）抛异常，第一阶段使用真实 Rename-Item
            Mock Rename-Item -MockWith { throw 'second stage rename error' } -ParameterFilter { $NewName -notlike '__tmp_*' }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*重命名失败*' } -Times 1 -Exactly
            # 半残状态断言：应全部为临时命名文件，不应出现最终命名格式的文件
            $TmpFiles = @(Get-ChildItem -LiteralPath $FinalPagesPath -Force | Where-Object { $PSItem.Name -match '^__tmp_' })
            $TmpFiles.Count | Should -Be 3
            $FinalNamedFiles = @(Get-ChildItem -LiteralPath $FinalPagesPath -Force | Where-Object { $PSItem.Name -match '^\d{3}\.' })
            $FinalNamedFiles.Count | Should -Be 0
        }

        It '应在第一阶段第 2 次迭代（i=1）失败：1 个 __tmp_ 文件 + 2 个原始文件' {
            Mock Write-LogEntry { }

            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'FirstStageMidFail'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [byte[]]$FakeImg = 0x01, 0x02
            [System.IO.File]::WriteAllBytes($WarningImg, $FakeImg)
            @('1.jpg', '2.jpg', '3.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), $FakeImg)
            }

            # Mock 第一阶段：第 1 次（i=2）手动模拟重命名成功，第 2 次抛异常
            $script:Stage1MidCall = 0
            Mock Rename-Item -MockWith {
                $script:Stage1MidCall++
                if ($script:Stage1MidCall -gt 1) { throw 'stage1 mid fail' }
                # 手动模拟重命名：复制内容到新文件名，删除原文件
                $Parent = Split-Path -Parent $LiteralPath
                Copy-Item -LiteralPath $LiteralPath -Destination (Join-Path -Path $Parent -ChildPath $NewName) -Force
                Remove-Item -LiteralPath $LiteralPath -Force
            } -ParameterFilter { $NewName -like '__tmp_*' }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*重命名失败*' } -Times 1 -Exactly
            # 半残：i=2 的 3.jpg 已被改名为 __tmp_002.jpg
            $TmpFiles = @(Get-ChildItem -LiteralPath $FinalPagesPath -Force | Where-Object { $PSItem.Name -match '^__tmp_' })
            $TmpFiles.Count | Should -Be 1
            # 2 个原始文件仍在（1.jpg, 2.jpg）
            $OrigFiles = @(Get-ChildItem -LiteralPath $FinalPagesPath -File -Force | Where-Object { $PSItem.Name -match '^\d+\.jpg$' })
            $OrigFiles.Count | Should -Be 2
        }

        It '应在第二阶段最后一次迭代（i=0）失败：2 个最终文件 + 1 个 __tmp_ 文件' {
            Mock Write-LogEntry { }

            $FinalPagesPath = Join-Path -Path $TestDrive -ChildPath 'SecondStageMidFail'
            New-Item -ItemType Directory -Path $FinalPagesPath -Force | Out-Null
            $WarningImg = Join-Path -Path $TestDrive -ChildPath 'warn.webp'
            [byte[]]$FakeImg = 0x01, 0x02
            [System.IO.File]::WriteAllBytes($WarningImg, $FakeImg)
            @('1.jpg', '2.jpg', '3.jpg') | ForEach-Object {
                [System.IO.File]::WriteAllBytes((Join-Path -Path $FinalPagesPath -ChildPath $PSItem), $FakeImg)
            }

            # 第一阶段使用真实 Rename-Item（无 mock 拦截 __tmp_* 命名）
            # 第二阶段：前 2 次（i=2→004, i=1→003）手动模拟成功，第 3 次（i=0→001）抛异常
            $script:Stage2MidCall = 0
            Mock Rename-Item -MockWith {
                $script:Stage2MidCall++
                if ($script:Stage2MidCall -gt 2) { throw 'stage2 last fail' }
                # 手动模拟重命名
                $Parent = Split-Path -Parent $LiteralPath
                Copy-Item -LiteralPath $LiteralPath -Destination (Join-Path -Path $Parent -ChildPath $NewName) -Force
                Remove-Item -LiteralPath $LiteralPath -Force
            } -ParameterFilter { $NewName -notlike '__tmp_*' }

            $Result = Invoke-FilePreparation -FinalPagesPath $FinalPagesPath -ImageExtensions @('.jpg') -WarningImagePath $WarningImg

            $Result | Should -Be 0
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*重命名失败*' } -Times 1 -Exactly
            # 半残：2 个最终文件（003.jpg, 004.jpg）+ 1 个 __tmp_ 文件（__tmp_000.jpg）
            $FinalNamed = @(Get-ChildItem -LiteralPath $FinalPagesPath -Force | Where-Object { $PSItem.Name -match '^\d{3}\.' })
            $FinalNamed.Count | Should -Be 2
            $TmpFiles = @(Get-ChildItem -LiteralPath $FinalPagesPath -Force | Where-Object { $PSItem.Name -match '^__tmp_' })
            $TmpFiles.Count | Should -Be 1
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
