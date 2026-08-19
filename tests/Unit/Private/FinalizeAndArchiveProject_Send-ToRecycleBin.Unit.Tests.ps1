#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Send-ToRecycleBin.ps1')
}

Describe 'Send-ToRecycleBin' {
    Context '参数与路径检查' {
        It '应将 Path 标记为 Mandatory 参数' {
            Get-Command Send-ToRecycleBin | Should -HaveParameter Path -Mandatory
        }

        It '应在路径不存在时静默返回（不抛异常、不调用删除）' {
            Mock Write-LogEntry { }
            Mock Add-Type { }
            Mock Remove-Item { }

            Send-ToRecycleBin -Path (Join-Path -Path $TestDrive -ChildPath 'Ghost.txt')

            Should -Not -Invoke Add-Type -Scope It
            Should -Not -Invoke Remove-Item -Scope It
        }
    }

    Context '文件类型分支（File 走 DeleteFile 分支）' {
        It '应在文件真实存在时成功删除（验证文件消失 = 移到回收站或删除）' {
            $TestFile = Join-Path -Path $TestDrive -ChildPath 'real_test.txt'
            'content' | Out-File -LiteralPath $TestFile -NoNewline -Encoding UTF8

            $TestFile | Should -Exist

            Send-ToRecycleBin -Path $TestFile

            # 验证文件不存在了（要么在回收站要么被删除，两者都满足"删除"语义）
            $TestFile | Should -Not -Exist
        }

        It '应正确处理相对路径文件' {
            $TestDir = Join-Path -Path $TestDrive -ChildPath 'relative_test_dir'
            New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
            $TestFile = Join-Path -Path $TestDir -ChildPath 'test.txt'
            'content' | Out-File -LiteralPath $TestFile -NoNewline -Encoding UTF8

            # 保存原始 Location 和 .NET CurrentDirectory 以便恢复
            $OriginalLocation = Get-Location
            $OriginalCurrentDir = [System.IO.Directory]::GetCurrentDirectory()
            try
            {
                # 同步 PowerShell Location 和 .NET CurrentDirectory，确保 Test-Path 和 VB 解析一致
                Set-Location -LiteralPath $TestDir
                [System.IO.Directory]::SetCurrentDirectory($TestDir)

                Send-ToRecycleBin -Path '.\test.txt'

                $TestFile | Should -Not -Exist
            }
            finally
            {
                Set-Location -LiteralPath $OriginalLocation
                [System.IO.Directory]::SetCurrentDirectory($OriginalCurrentDir)
            }
        }

        It '应正确处理含空格的文件路径' {
            $TestFile = Join-Path -Path $TestDrive -ChildPath 'file with spaces.txt'
            'content' | Out-File -LiteralPath $TestFile -NoNewline -Encoding UTF8

            Send-ToRecycleBin -Path $TestFile

            $TestFile | Should -Not -Exist
        }
    }

    Context '目录类型分支（Container 走 DeleteDirectory 分支）' {
        It '应在目录真实存在时成功删除整个目录（目录消失）' {
            $TestDir = Join-Path -Path $TestDrive -ChildPath 'dir_to_delete'
            New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
            $ChildFile = Join-Path -Path $TestDir -ChildPath 'nested.txt'
            'nested' | Out-File -LiteralPath $ChildFile -NoNewline -Encoding UTF8

            $TestDir | Should -Exist

            Send-ToRecycleBin -Path $TestDir

            $TestDir | Should -Not -Exist
        }

        It '应处理路径包含方括号的目录' {
            $BracketDir = Join-Path -Path $TestDrive -ChildPath '2026_[test]_bracket'
            # 使用 .NET 方法避免 PowerShell 路径通配符解释
            [System.IO.Directory]::CreateDirectory($BracketDir) | Out-Null
            $ChildFile = Join-Path -Path $BracketDir -ChildPath 'nested.txt'
            [System.IO.File]::WriteAllText($ChildFile, 'nested')

            (Test-Path -LiteralPath $BracketDir) | Should -Be $true

            Send-ToRecycleBin -Path $BracketDir

            (Test-Path -LiteralPath $BracketDir) | Should -Be $false
        }

        It '应正确处理含空格的目录路径' {
            $TestDir = Join-Path -Path $TestDrive -ChildPath 'dir with spaces'
            New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
            $ChildFile = Join-Path -Path $TestDir -ChildPath 'child.txt'
            'child' | Out-File -LiteralPath $ChildFile -NoNewline -Encoding UTF8

            Send-ToRecycleBin -Path $TestDir

            $TestDir | Should -Not -Exist
        }

        It '应在目录正常删除时不降级为 Remove-Item' {
            $TestDir = Join-Path -Path $TestDrive -ChildPath 'no_degrade_dir'
            New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
            $ChildFile = Join-Path -Path $TestDir -ChildPath 'a.txt'
            'a' | Out-File -LiteralPath $ChildFile -NoNewline -Encoding UTF8

            Mock Write-LogEntry { }
            Mock Remove-Item { }

            Send-ToRecycleBin -Path $TestDir

            # VB 成功删除目录，不应触发 catch 降级
            Should -Not -Invoke Remove-Item -Scope It
        }
    }

    Context '降级为永久删除（catch 分支）' {
        It '应在 Add-Type 加载程序集失败时降级为 Remove-Item 并输出 Warning 日志' {
            $TestFile = Join-Path -Path $TestDrive -ChildPath 'addtype_fail.txt'
            'content' | Out-File -LiteralPath $TestFile -NoNewline -Encoding UTF8

            Mock Write-LogEntry { }
            Mock Add-Type -MockWith { throw '程序集加载失败' }
            Mock Remove-Item { }

            Send-ToRecycleBin -Path $TestFile

            # Remove-Item 是 PowerShell 内置命令，不是被测代码，验证它"真的删了"是在测 PowerShell 而非 Send-ToRecycleBin。
            # catch 分支：写 Warning 日志 + 调用 Remove-Item
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*回收站操作失败*' } -Times 1 -Exactly
            Should -Invoke Remove-Item -Scope It -ParameterFilter { $LiteralPath -eq $TestFile } -Times 1 -Exactly
        }

        It '应在文件被独占锁定导致 VB DeleteFile 失败时降级为 Remove-Item' {
            $TestFile = Join-Path -Path $TestDrive -ChildPath 'locked.txt'
            'content' | Out-File -LiteralPath $TestFile -NoNewline -Encoding UTF8

            # 独占锁定文件（FileShare.None），VB DeleteFile 无法移动到回收站
            $Stream = [System.IO.File]::Open($TestFile, 'Open', 'Read', 'None')

            try
            {
                Mock Write-LogEntry { }
                Mock Remove-Item { }

                Send-ToRecycleBin -Path $TestFile

                Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*回收站操作失败*' } -Times 1 -Exactly
                Should -Invoke Remove-Item -Scope It -ParameterFilter { $LiteralPath -eq $TestFile } -Times 1 -Exactly
            }
            finally
            {
                # 确保文件流被释放，避免 TestDrive 清理失败
                $Stream.Close()
                $Stream.Dispose()
            }
        }

        It '应在路径不存在但 Test-Path 被欺骗返回 true 时触发 VB 失败降级' {
            $FakePath = Join-Path -Path $TestDrive -ChildPath 'nonexistent_for_vb_fail.txt'

            Mock Write-LogEntry { }
            Mock Remove-Item { }
            # 欺骗存在性检查和类型检查：Test-Path 始终返回 true，但路径实际不存在
            Mock Test-Path -MockWith { return $true }

            Send-ToRecycleBin -Path $FakePath

            # VB DeleteDirectory 对不存在的路径抛异常 → catch 降级
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*回收站操作失败*' } -Times 1 -Exactly
            Should -Invoke Remove-Item -Scope It -ParameterFilter { $LiteralPath -eq $FakePath } -Times 1 -Exactly
        }

        It '应在 Test-Path 判定为文件但实际为目录时仍成功删除（VB DeleteFile 对目录也能工作）' {
            $TestDir = Join-Path -Path $TestDrive -ChildPath 'race_dir_to_file'
            New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

            Mock Write-LogEntry { }
            Mock Remove-Item { }
            # 欺骗类型检查：Container 检查返回 false（假装是文件），实际是目录
            # -not $PSBoundParameters.ContainsKey('PathType') 精确区分了两次调用：
            # 第一次无 PathType → 返回 true（放行），第二次有PathType→返回false（欺骗走文件分支）
            Mock Test-Path -MockWith { return -not $PSBoundParameters.ContainsKey('PathType') }

            Send-ToRecycleBin -Path $TestDir

            # VB DeleteFile 对目录路径不抛异常，优雅处理，不触发 catch 降级
            Should -Not -Invoke Remove-Item -Scope It
            Should -Not -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' }
        }

        It '应在 Test-Path 判定为目录但实际为文件时触发 catch 降级' {
            $TestFile = Join-Path -Path $TestDrive -ChildPath 'race_file_to_dir.txt'
            'content' | Out-File -LiteralPath $TestFile -NoNewline -Encoding UTF8

            Mock Write-LogEntry { }
            Mock Remove-Item { }
            # 欺骗类型检查：Container 检查返回 true（假装是目录），实际是文件
            Mock Test-Path -MockWith { return $true }

            Send-ToRecycleBin -Path $TestFile

            # VB DeleteDirectory 对文件路径抛异常 → catch 降级
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*回收站操作失败*' } -Times 1 -Exactly
            Should -Invoke Remove-Item -Scope It -ParameterFilter { $LiteralPath -eq $TestFile } -Times 1 -Exactly
        }
    }
}
