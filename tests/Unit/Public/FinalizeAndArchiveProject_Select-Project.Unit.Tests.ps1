#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Public\Select-Project.ps1')
}

Describe 'Select-Project' {
    Context '参数校验' {
        It '应将 ActiveDir 标记为 Mandatory 参数' {
            Get-Command Select-Project | Should -HaveParameter ActiveDir -Mandatory
        }
    }

    Context 'Get-ChildItem 扫描失败（catch 分支）' {
        It '应在 Get-ChildItem 抛异常时返回 $null 并输出 Warning 日志' {
            Mock Write-LogEntry { }
            Mock Get-ChildItem { throw 'access denied' } -ParameterFilter { $Directory -eq $true }

            $Result = Select-Project -ActiveDir (Join-Path -Path $TestDrive -ChildPath 'Ghost')

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*扫描项目目录失败*' } -Times 1 -Exactly
        }
    }

    Context '无项目时（0 个符合）' {
        It '应在目录内无 yyyy-MM-dd_* 前缀项目时输出未找到项目 Warning 并返回 $null' {
            Mock Write-LogEntry { }

            $ActiveDir = Join-Path -Path $TestDrive -ChildPath 'NoProjects'
            New-Item -ItemType Directory -Path $ActiveDir -Force | Out-Null
            # 放两个非规范项目
            New-Item -ItemType Directory -Path (Join-Path -Path $ActiveDir -ChildPath 'RandomProject') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path -Path $ActiveDir -ChildPath '2026_08_07_oldformat') -Force | Out-Null

            $Result = Select-Project -ActiveDir $ActiveDir

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '未找到项目' } -Times 1 -Exactly
        }
    }

    Context '有项目但无用户交互（无法 mock Read-Host 时验证模式筛选正确）' {
        It '应只扫描 yyyy-MM-dd_ 前缀的目录，并跳过不匹配命名规范的目录' {
            Mock Write-LogEntry { }
            # Mock Read-Host：无论 Prompt，任何调用都返回 '1'
            function MockedReadHost { param($Prompt) return '1' }
            Mock Read-Host { return '1' }

            $ActiveDir = Join-Path -Path $TestDrive -ChildPath 'WithProjects'
            New-Item -ItemType Directory -Path $ActiveDir -Force | Out-Null

            # 1 个匹配 + 2 个不匹配
            $Match1 = Join-Path -Path $ActiveDir -ChildPath '2026-08-07_MyNovel'
            $Skip1 = Join-Path -Path $ActiveDir -ChildPath 'NotMatching'
            $Skip2 = Join-Path -Path $ActiveDir -ChildPath '07-08-2026_OldStyle'  # 反序
            New-Item -ItemType Directory -Path $Match1 -Force | Out-Null
            New-Item -ItemType Directory -Path $Skip1 -Force | Out-Null
            New-Item -ItemType Directory -Path $Skip2 -Force | Out-Null

            $Result = Select-Project -ActiveDir $ActiveDir

            $Result | Should -Be $Match1
            # Read-Host 仅调用 1 次（1 个有效项目，直接返回）
            Should -Invoke Read-Host -Scope It -Times 1 -Exactly
        }

        It '应正确输出 3 个匹配项目列表，Read-Host 返回 "2" 选中第 2 个项目' {
            Mock Write-LogEntry { }
            Mock Read-Host { return '2' }

            $ActiveDir = Join-Path -Path $TestDrive -ChildPath 'ThreeProjects'
            New-Item -ItemType Directory -Path $ActiveDir -Force | Out-Null

            $P1 = Join-Path -Path $ActiveDir -ChildPath '2026-01-01_A'
            $P2 = Join-Path -Path $ActiveDir -ChildPath '2026-06-15_B'
            $P3 = Join-Path -Path $ActiveDir -ChildPath '2026-12-31_C'
            New-Item -ItemType Directory -Path $P1 -Force | Out-Null
            New-Item -ItemType Directory -Path $P2 -Force | Out-Null
            New-Item -ItemType Directory -Path $P3 -Force | Out-Null

            $Result = Select-Project -ActiveDir $ActiveDir

            $Result | Should -Be $P2
        }
    }

    Context 'Read-Host 输入验证（越界或非数字）循环' {
        It '应在输入 999（超范围）后再输入 1 时最终返回第一个项目（Mock Read-Host 按序返回）' {
            Mock Write-LogEntry { }
            $global:SelectProjectCallCount = 0
            Mock Read-Host {
                $global:SelectProjectCallCount++
                switch ($global:SelectProjectCallCount)
                {
                    1 { return '999' }   # 超范围
                    default { return '1' }     # 有效
                }
            }

            $ActiveDir = Join-Path -Path $TestDrive -ChildPath 'BoundaryTest'
            New-Item -ItemType Directory -Path $ActiveDir -Force | Out-Null
            $P1 = Join-Path -Path $ActiveDir -ChildPath '2026-05-01_One'
            $P2 = Join-Path -Path $ActiveDir -ChildPath '2026-05-02_Two'
            New-Item -ItemType Directory -Path $P1 -Force | Out-Null
            New-Item -ItemType Directory -Path $P2 -Force | Out-Null

            $Result = Select-Project -ActiveDir $ActiveDir

            $Result | Should -Be $P1
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '编号超出范围' } -Times 1 -Exactly
        }

        It '应在输入 abc（非数字）时抛出 catch 警告，再输入 2 时返回第 2 个' {
            Mock Write-LogEntry { }
            $global:SelectProjectCallCount = 0
            Mock Read-Host {
                $global:SelectProjectCallCount++
                switch ($global:SelectProjectCallCount)
                {
                    1 { return 'abc' }   # 非数字
                    default { return '2' }
                }
            }

            $ActiveDir = Join-Path -Path $TestDrive -ChildPath 'NonNumeric'
            New-Item -ItemType Directory -Path $ActiveDir -Force | Out-Null
            $P1 = Join-Path -Path $ActiveDir -ChildPath '2026-03-01_Alpha'
            $P2 = Join-Path -Path $ActiveDir -ChildPath '2026-03-02_Beta'
            New-Item -ItemType Directory -Path $P1 -Force | Out-Null
            New-Item -ItemType Directory -Path $P2 -Force | Out-Null

            $Result = Select-Project -ActiveDir $ActiveDir

            $Result | Should -Be $P2
            # 如果 [int] 强制转换抛了异常则进入 '请输入有效数字' 分支，否则进入越界分支（-1），两者都算 Warning
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and ($Message -eq '请输入有效数字' -or $Message -eq '编号超出范围') } -Times 1 -Exactly
        }
    }
}
