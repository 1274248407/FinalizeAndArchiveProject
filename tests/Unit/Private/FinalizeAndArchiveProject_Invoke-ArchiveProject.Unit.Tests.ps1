#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Invoke-ArchiveProject.ps1')
}

Describe 'Invoke-ArchiveProject' {
    Context '参数校验' {
        It '应将 ProjectDir 标记为 Mandatory 参数' {
            Get-Command Invoke-ArchiveProject | Should -HaveParameter ProjectDir -Mandatory
        }
        It '应将 ArchiveDir 标记为 Mandatory 参数' {
            Get-Command Invoke-ArchiveProject | Should -HaveParameter ArchiveDir -Mandatory
        }
    }

    Context '真实 Move-Item 成功（含方括号路径）' {
        It '应将普通目录移动到归档目录并返回 $true' {
            Mock Write-LogEntry { }

            $RootDir = Join-Path -Path $TestDrive -ChildPath 'ArchiveRoot'
            New-Item -ItemType Directory -Path $RootDir -Force | Out-Null

            $ProjectDir = Join-Path -Path $RootDir -ChildPath 'MyProject'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            $ChildFile = Join-Path -Path $ProjectDir -ChildPath 'readme.md'
            'content' | Out-File -LiteralPath $ChildFile -NoNewline -Encoding UTF8

            $ArchiveDir = Join-Path -Path $RootDir -ChildPath 'Archive'
            New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

            $Result = Invoke-ArchiveProject -ProjectDir $ProjectDir -ArchiveDir $ArchiveDir

            $Result | Should -Be $true
            (Test-Path -LiteralPath $ProjectDir) | Should -Be $false
            $Dest = Join-Path -Path $ArchiveDir -ChildPath 'MyProject'
            (Test-Path -LiteralPath $Dest) | Should -Be $true
            # 验证文件存在 + 内容被完整保留（捕获"空壳归档"假成功）
            $DestReadme = Join-Path -Path $Dest -ChildPath 'readme.md'
            (Test-Path -LiteralPath $DestReadme) | Should -Be $true
            Get-Content -LiteralPath $DestReadme -Raw | Should -Be 'content'
        }

        It '应处理项目名含方括号路径（LiteralPath）' {
            Mock Write-LogEntry { }

            $RootDir = Join-Path -Path $TestDrive -ChildPath 'ArchiveRoot2'
            New-Item -ItemType Directory -Path $RootDir -Force | Out-Null

            $BracketProject = Join-Path -Path $RootDir -ChildPath '2026_[test]_Proj'
            [System.IO.Directory]::CreateDirectory($BracketProject) | Out-Null
            $ChildFile = Join-Path -Path $BracketProject -ChildPath 'readme.md'
            [System.IO.File]::WriteAllText($ChildFile, 'content')

            $ArchiveDir = Join-Path -Path $RootDir -ChildPath 'Archive2'
            [System.IO.Directory]::CreateDirectory($ArchiveDir) | Out-Null

            $Result = Invoke-ArchiveProject -ProjectDir $BracketProject -ArchiveDir $ArchiveDir

            $Result | Should -Be $true
            (Test-Path -LiteralPath $BracketProject) | Should -Be $false
            $Dest = Join-Path -Path $ArchiveDir -ChildPath '2026_[test]_Proj'
            (Test-Path -LiteralPath $Dest) | Should -Be $true
            # 验证文件存在 + 内容被完整保留（捕获"空壳归档"假成功）
            $DestReadme = Join-Path -Path $Dest -ChildPath 'readme.md'
            (Test-Path -LiteralPath $DestReadme) | Should -Be $true
            Get-Content -LiteralPath $DestReadme -Raw | Should -Be 'content'
        }
    }

    Context '移动失败（catch 分支）' {
        It '应在 Move-Item 抛异常时返回 $false 并输出 Warning 日志' {
            Mock Write-LogEntry { }
            Mock Move-Item { throw 'network down' }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'FakeProject'
            $ArchiveDir = Join-Path -Path $TestDrive -ChildPath 'Archive'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

            $Result = Invoke-ArchiveProject -ProjectDir $ProjectDir -ArchiveDir $ArchiveDir

            $Result | Should -Be $false
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*归档失败*' } -Times 1 -Exactly
        }
    }

    Context '移动验证失败（真值表覆盖：除成功态 (F,T) 外的 3 种失败态均应 throw）' {
        It '应在 (T, F) 残留态：Move-Item 未真正移动时抛出并进入 catch，返回 $false' {
            Mock Write-LogEntry { }
            # Mock Move-Item 但不真正移动（不抛异常），验证阶段会检测失败并 throw
            Mock Move-Item { }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'NotMoved'
            $ArchiveDir = Join-Path -Path $TestDrive -ChildPath 'ArchiveN'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

            $Result = Invoke-ArchiveProject -ProjectDir $ProjectDir -ArchiveDir $ArchiveDir

            $Result | Should -Be $false
            # 源仍未被移动（A=T）
            (Test-Path -LiteralPath $ProjectDir) | Should -Be $true
            # 目标项目目录未被创建（B=F，注意是 Destination 而非归档根目录 ArchiveDir）
            $Destination = Join-Path -Path $ArchiveDir -ChildPath 'NotMoved'
            (Test-Path -LiteralPath $Destination) | Should -Be $false
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*归档失败*' } -Times 1 -Exactly
        }

        It '应在 (T, T) 残留态：源还在且目标已存在时抛出并返回 $false' {
            Mock Write-LogEntry { }
            # Mock Move-Item 什么都不做：源不动、预存的目标也不删
            Mock Move-Item { }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'Residual'
            $ArchiveDir = Join-Path -Path $TestDrive -ChildPath 'ArchiveTT'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

            # 预先在归档目录创建同名项目（模拟目标已存在）
            $PreExistingDest = Join-Path -Path $ArchiveDir -ChildPath 'Residual'
            New-Item -ItemType Directory -Path $PreExistingDest -Force | Out-Null

            $Result = Invoke-ArchiveProject -ProjectDir $ProjectDir -ArchiveDir $ArchiveDir

            $Result | Should -Be $false
            # 源仍在
            (Test-Path -LiteralPath $ProjectDir) | Should -Be $true
            # 预存目标也仍在
            (Test-Path -LiteralPath $PreExistingDest) | Should -Be $true
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*归档失败*' } -Times 1 -Exactly
        }

        It '应在 (F, F) 数据丢失态：源被删但目标未创建时抛出并返回 $false（防退化关键用例）' {
            Mock Write-LogEntry { }

            $ProjectDir = Join-Path -Path $TestDrive -ChildPath 'LostData'
            $ArchiveDir = Join-Path -Path $TestDrive -ChildPath 'ArchiveFF'
            New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
            New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null

            # Mock Move-Item：删除源但不创建目标（模拟跨卷移动中断 / 数据丢失）
            Mock Move-Item {
                Remove-Item -LiteralPath $ProjectDir -Recurse -Force
            }

            $Result = Invoke-ArchiveProject -ProjectDir $ProjectDir -ArchiveDir $ArchiveDir

            $Result | Should -Be $false
            # 源已消失
            (Test-Path -LiteralPath $ProjectDir) | Should -Be $false
            # 目标未创建
            $Dest = Join-Path -Path $ArchiveDir -ChildPath 'LostData'
            (Test-Path -LiteralPath $Dest) | Should -Be $false
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*归档失败*' } -Times 1 -Exactly
        }
    }
}
