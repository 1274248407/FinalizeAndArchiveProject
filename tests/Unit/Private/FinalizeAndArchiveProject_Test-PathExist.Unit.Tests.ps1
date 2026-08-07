#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Test-PathExist.ps1')
}

Describe 'Test-PathExist' {
    Context '参数校验' {
        It '应将 Paths 标记为 Mandatory 参数' {
            Get-Command Test-PathExist | Should -HaveParameter Paths -Mandatory
        }

        It '应在传入空数组时抛出参数绑定异常（[string[]] 不接受空数组）' {
            { Test-PathExist -Paths @() } | Should -Throw
        }
    }

    Context '路径存在' {
        It '应在单一路径存在时返回 $true' {
            Mock Write-LogEntry { }
            $ExistingFile = Join-Path -Path $TestDrive -ChildPath 'exists.txt'
            New-Item -ItemType File -Path $ExistingFile -Force | Out-Null

            $Result = Test-PathExist -Paths @($ExistingFile)

            $Result | Should -Be $true
        }

        It '应在多个路径都存在时返回 $true' {
            Mock Write-LogEntry { }
            $File1 = Join-Path -Path $TestDrive -ChildPath 'a.txt'
            $File2 = Join-Path -Path $TestDrive -ChildPath 'b.txt'
            $Dir1 = Join-Path -Path $TestDrive -ChildPath 'subdir'
            New-Item -ItemType File -Path $File1 -Force | Out-Null
            New-Item -ItemType File -Path $File2 -Force | Out-Null
            New-Item -ItemType Directory -Path $Dir1 -Force | Out-Null

            $Result = Test-PathExist -Paths @($File1, $File2, $Dir1)

            $Result | Should -Be $true
        }

        It '应正确处理路径中的方括号特殊字符（使用 -LiteralPath）' {
            Mock Write-LogEntry { }
            $BracketFile = Join-Path -Path $TestDrive -ChildPath '2026-07-24_[test].txt'
            [System.IO.File]::WriteAllText($BracketFile, 'content')

            $Result = Test-PathExist -Paths @($BracketFile)

            $Result | Should -Be $true
        }

        It '应正确处理混合的文件和目录路径' {
            Mock Write-LogEntry { }
            $File = Join-Path -Path $TestDrive -ChildPath 'readme.txt'
            $Dir = Join-Path -Path $TestDrive -ChildPath 'assets'
            New-Item -ItemType File -Path $File -Force | Out-Null
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null

            $Result = Test-PathExist -Paths @($File, $Dir)

            $Result | Should -Be $true
        }
    }

    Context '路径不存在' {
        It '应在单一路径不存在时返回 $false 并输出 Warning 日志' {
            Mock Write-LogEntry { }
            $NotExist = Join-Path -Path $TestDrive -ChildPath 'ghost.txt'

            $Result = Test-PathExist -Paths @($NotExist)

            $Result | Should -Be $false
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*ghost.txt*' }
        }

        It '应在多个路径中第一个不存在时立即返回（短路求值）' {
            Mock Write-LogEntry { }
            $Existing = Join-Path -Path $TestDrive -ChildPath 'real.txt'
            New-Item -ItemType File -Path $Existing -Force | Out-Null
            $NotExist1 = Join-Path -Path $TestDrive -ChildPath 'missing1.txt'
            $NotExist2 = Join-Path -Path $TestDrive -ChildPath 'missing2.txt'

            $Result = Test-PathExist -Paths @($Existing, $NotExist1, $NotExist2)

            $Result | Should -Be $false
            # 只应输出 1 次 Warning（在 NotExist1 处短路）
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' } -Times 1 -Exactly
        }

        It '应在多个路径全部不存在时返回 $false（只报告第一个）' {
            Mock Write-LogEntry { }
            $NotExist1 = Join-Path -Path $TestDrive -ChildPath 'ghost1.txt'
            $NotExist2 = Join-Path -Path $TestDrive -ChildPath 'ghost2.txt'

            $Result = Test-PathExist -Paths @($NotExist1, $NotExist2)

            $Result | Should -Be $false
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*ghost1.txt*' } -Times 1 -Exactly
        }

        It '应在传入包含空字符串的数组时抛出参数绑定异常' {
            { Test-PathExist -Paths @('') } | Should -Throw
        }
    }
}
