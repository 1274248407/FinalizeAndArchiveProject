#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Update-ReadmeProgress.ps1')

    function New-ReadmeTemplate
    {
        return @(
            '# Project',
            '',
            '## 进度',
            '- [ ] 文件整理与分离',
            '- [ ] OCR 处理与校对',
            '- [ ] Inpainting 处理与修正',
            '- [ ] 文本翻译',
            '- [ ] 最终质量检查',
            '- [ ] 嵌字 (完成至页 0)',
            ''
        ) -join "`n"
    }
}

Describe 'Update-ReadmeProgress' {
    Context '参数校验' {
        It '应将 ProjectDir 标记为 Mandatory 参数' {
            Get-Command Update-ReadmeProgress | Should -HaveParameter ProjectDir -Mandatory
        }
        It '应将 TotalPages 标记为 Mandatory 参数' {
            Get-Command Update-ReadmeProgress | Should -HaveParameter TotalPages -Mandatory
        }
    }

    Context 'README.md 不存在' {
        It '应静默返回（不抛异常，不写日志）' {
            Mock Write-LogEntry { }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'NoReadme'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null

            { Update-ReadmeProgress -ProjectDir $ProjectDir -TotalPages 42 -Confirm:$false } | Should -Not -Throw

            Should -Not -Invoke Write-LogEntry -Scope It
        }
    }

    Context 'README.md 存在并更新' {
        BeforeEach {
            Mock Write-LogEntry { }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'WithReadme'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            $ReadmePath = Join-Path -Path $ProjectDir -ChildPath 'README.md'
            [System.IO.File]::WriteAllText($ReadmePath, (New-ReadmeTemplate))
        }

        It '应将 5 项待办全部改为 [X]，并更新嵌字为 "完成至页 42"' {
            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'WithReadme'

            Update-ReadmeProgress -ProjectDir $ProjectDir -TotalPages 42 -Confirm:$false

            $Content = Get-Content -LiteralPath (Join-Path -Path $ProjectDir -ChildPath 'README.md') -Raw
            # 验证 5 项 TODO
            $Content | Should -Match '- \[X\] 文件整理与分离'
            $Content | Should -Match '- \[X\] OCR 处理与校对'
            $Content | Should -Match '- \[X\] Inpainting 处理与修正'
            $Content | Should -Match '- \[X\] 文本翻译'
            $Content | Should -Match '- \[X\] 最终质量检查'
            # 验证嵌字
            $Content | Should -Match '- \[X\] 嵌字 \(完成至页 42\)'
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Success' -and $Message -eq 'README更新完成' } -Times 1 -Exactly
        }

        It '应处理 TotalPages=3 位数边界（完成至页 100）' {
            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'WithReadme'

            Update-ReadmeProgress -ProjectDir $ProjectDir -TotalPages 100 -Confirm:$false

            $Content = Get-Content -LiteralPath (Join-Path -Path $ProjectDir -ChildPath 'README.md') -Raw
            $Content | Should -Match '- \[X\] 嵌字 \(完成至页 100\)'
        }
    }

    Context 'Get-Content / Set-Content 抛异常（catch 分支）' {
        It '应在文件读取抛异常时输出 Warning 并吞掉异常' {
            Mock Write-LogEntry { }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'ReadmeError'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            $ReadmePath = Join-Path -Path $ProjectDir -ChildPath 'README.md'
            [System.IO.File]::WriteAllText($ReadmePath, (New-ReadmeTemplate))

            Mock Get-Content { throw 'file permission error' }

            { Update-ReadmeProgress -ProjectDir $ProjectDir -TotalPages 10 -Confirm:$false } | Should -Not -Throw

            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*README更新失败*' } -Times 1 -Exactly
        }
    }
}
