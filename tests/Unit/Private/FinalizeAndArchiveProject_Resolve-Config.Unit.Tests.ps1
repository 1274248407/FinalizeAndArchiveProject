#Requires -Modules Pester
#Requires -Modules PSToml

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\ConfigManager.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Resolve-Config.ps1')
}

Describe 'Resolve-Config' {
    Context '指定 ConfigPath' {
        It '应在指定的合法配置文件存在时返回完整的 PSCustomObject 配置对象' {
            Mock Write-LogEntry { }
            $ConfigFile = Join-Path -Path $TestDrive -ChildPath 'valid.toml'

            $TomlContent = @'
[paths]
active_dir = 'D:\translation\active'
archive_dir = 'D:\translation\archive'
warning_image = 'D:\translation\warning.png'

[settings]
image_extensions = [".JPG", ".PNG", ".WebP"]
'@
            $TomlContent | Out-File -LiteralPath $ConfigFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $ConfigFile

            $Result | Should -Not -Be $null
            $Result | Should -BeOfType [PSCustomObject]

            # 断言各字段值正确
            $Result.ActiveDir | Should -Be 'D:\translation\active'
            $Result.ArchiveDir | Should -Be 'D:\translation\archive'
            $Result.WarningImagePath | Should -Be 'D:\translation\warning.png'

            # ImageExtensions 应全部小写化
            $Result.ImageExtensions.Count | Should -Be 3
            @($Result.ImageExtensions | Sort-Object) -join ',' | Should -Be '.jpg,.png,.webp'
        }

        It '应在指定的配置文件不存在时返回 $null（ConfigManager 返回 $null）' {
            Mock Write-LogEntry { }
            $NotExist = Join-Path -Path $TestDrive -ChildPath 'ghost.toml'

            $Result = Resolve-Config -ConfigPath $NotExist

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*配置加载失败*' } -Times 1 -Exactly
        }

        It '应在 TOML 文件存在但格式非法时返回 $null' {
            Mock Write-LogEntry { }
            $BadFile = Join-Path -Path $TestDrive -ChildPath 'broken.toml'
            '[paths broken' | Out-File -LiteralPath $BadFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $BadFile

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*配置加载失败*' } -Times 1 -Exactly
        }

        It '应在 TOML 合法但缺少 settings 节时返回 $null（访问 $null.image_extensions 触发 catch）' {
            Mock Write-LogEntry { }
            $PartialFile = Join-Path -Path $TestDrive -ChildPath 'partial.toml'

            # 只有 paths 节，缺少 settings 节 → 访问 $null.image_extensions 异常
            $TomlContent = @'
[paths]
active_dir = 'D:\a'
archive_dir = 'D:\b'
warning_image = 'D:\c.png'
'@
            $TomlContent | Out-File -LiteralPath $PartialFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $PartialFile

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*配置键缺失*' } -Times 1 -Exactly
        }

        It '应在 TOML 合法但 image_extensions 字段缺失时返回 $null' {
            Mock Write-LogEntry { }
            $MissingExtFile = Join-Path -Path $TestDrive -ChildPath 'missing_ext.toml'

            # 缺少 image_extensions
            $TomlContent = @'
[paths]
active_dir = 'D:\a'
archive_dir = 'D:\b'
warning_image = 'D:\c.png'

[settings]
'@
            $TomlContent | Out-File -LiteralPath $MissingExtFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $MissingExtFile

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*配置键缺失*' } -Times 1 -Exactly
        }

        It '应在 TOML 合法但 paths.active_dir 缺失时返回对象且 ActiveDir 为 $null' {
            Mock Write-LogEntry { }
            $MissingActiveFile = Join-Path -Path $TestDrive -ChildPath 'missing_active.toml'

            $TomlContent = @'
[paths]
archive_dir = 'D:\b'
warning_image = 'D:\c.png'

[settings]
image_extensions = [".jpg"]
'@
            $TomlContent | Out-File -LiteralPath $MissingActiveFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $MissingActiveFile

            # PowerShell 访问不存在的属性返回 $null 不抛异常，不触发 catch
            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be $null
            $Result.ArchiveDir | Should -Be 'D:\b'
            $Result.WarningImagePath | Should -Be 'D:\c.png'
            $Result.ImageExtensions.Count | Should -Be 1
            $Result.ImageExtensions | Should -Be '.jpg'
        }

        It '应在 TOML 合法但 archive_dir 缺失时返回对象且 ArchiveDir 为 $null' {
            Mock Write-LogEntry { }
            $MissingArchiveFile = Join-Path -Path $TestDrive -ChildPath 'missing_archive.toml'

            $TomlContent = @'
[paths]
active_dir = 'D:\a'
warning_image = 'D:\c.png'

[settings]
image_extensions = [".jpg"]
'@
            $TomlContent | Out-File -LiteralPath $MissingArchiveFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $MissingArchiveFile

            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be 'D:\a'
            $Result.ArchiveDir | Should -Be $null
            $Result.WarningImagePath | Should -Be 'D:\c.png'
            $Result.ImageExtensions.Count | Should -Be 1
            $Result.ImageExtensions | Should -Be '.jpg'
        }

        It '应在 TOML 合法但 warning_image 缺失时返回对象且 WarningImagePath 为 $null' {
            Mock Write-LogEntry { }
            $MissingWarningFile = Join-Path -Path $TestDrive -ChildPath 'missing_warning.toml'

            $TomlContent = @'
[paths]
active_dir = 'D:\a'
archive_dir = 'D:\b'

[settings]
image_extensions = [".jpg"]
'@
            $TomlContent | Out-File -LiteralPath $MissingWarningFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $MissingWarningFile

            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be 'D:\a'
            $Result.ArchiveDir | Should -Be 'D:\b'
            $Result.WarningImagePath | Should -Be $null
            $Result.ImageExtensions.Count | Should -Be 1
            $Result.ImageExtensions | Should -Be '.jpg'
        }

        It '应在 TOML 合法但缺少整个 paths 节时返回对象且路径字段全为 $null' {
            Mock Write-LogEntry { }
            $NoPathsFile = Join-Path -Path $TestDrive -ChildPath 'no_paths.toml'

            $TomlContent = @'
[settings]
image_extensions = [".jpg"]
'@
            $TomlContent | Out-File -LiteralPath $NoPathsFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $NoPathsFile

            # 缺整个 paths 节：$Config.paths 为 $null，属性访问返回 $null 不抛异常
            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be $null
            $Result.ArchiveDir | Should -Be $null
            $Result.WarningImagePath | Should -Be $null
            $Result.ImageExtensions.Count | Should -Be 1
            $Result.ImageExtensions | Should -Be '.jpg'
        }

        It '应在 image_extensions 为空数组时返回有效对象且 ImageExtensions 为空' {
            Mock Write-LogEntry { }
            $EmptyExtFile = Join-Path -Path $TestDrive -ChildPath 'empty_ext.toml'

            $TomlContent = @'
[paths]
active_dir = 'D:\a'
archive_dir = 'D:\b'
warning_image = 'D:\c.png'

[settings]
image_extensions = []
'@
            $TomlContent | Out-File -LiteralPath $EmptyExtFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $EmptyExtFile

            $Result | Should -Not -Be $null
            $Result.ImageExtensions.Count | Should -Be 0
        }

        It '应在 image_extensions 含非字符串元素时返回 $null（ToLower 失败进入 catch）' {
            Mock Write-LogEntry { }
            $NonStringFile = Join-Path -Path $TestDrive -ChildPath 'nonstring_ext.toml'

            $TomlContent = @'
[paths]
active_dir = 'D:\a'
archive_dir = 'D:\b'
warning_image = 'D:\c.png'

[settings]
image_extensions = [123, 456]
'@
            $TomlContent | Out-File -LiteralPath $NonStringFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $NonStringFile

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*配置键缺失*' } -Times 1 -Exactly
        }

        It '应正确处理路径中包含方括号的配置文件' {
            Mock Write-LogEntry { }
            $BracketFile = Join-Path -Path $TestDrive -ChildPath '2026_[test].toml'

            $TomlContent = @'
[paths]
active_dir = 'D:\a'
archive_dir = 'D:\b'
warning_image = 'D:\c.png'

[settings]
image_extensions = [".jpg"]
'@
            [System.IO.File]::WriteAllText($BracketFile, $TomlContent)

            $Result = Resolve-Config -ConfigPath $BracketFile

            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be 'D:\a'
            $Result.ArchiveDir | Should -Be 'D:\b'
            $Result.WarningImagePath | Should -Be 'D:\c.png'
            $Result.ImageExtensions.Count | Should -Be 1
            $Result.ImageExtensions | Should -Be '.jpg'
        }

        It '应正确小写化全部 3 个 image_extensions 元素' {
            Mock Write-LogEntry { }
            $ConfigFile = Join-Path -Path $TestDrive -ChildPath 'three_ext.toml'

            $TomlContent = @'
[paths]
active_dir = 'D:\a'
archive_dir = 'D:\b'
warning_image = 'D:\c.png'

[settings]
image_extensions = [".JPG", ".WEBP", ".GIF"]
'@
            $TomlContent | Out-File -LiteralPath $ConfigFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config -ConfigPath $ConfigFile

            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be 'D:\a'
            $Result.ArchiveDir | Should -Be 'D:\b'
            $Result.WarningImagePath | Should -Be 'D:\c.png'
            @($Result.ImageExtensions | Sort-Object) -join ',' | Should -Be '.gif,.jpg,.webp'
        }
    }

    Context '自动搜索配置文件（未指定 ConfigPath）' {
        BeforeAll {
            $ValidToml = @'
[paths]
active_dir = 'D:\a'
archive_dir = 'D:\b'
warning_image = 'D:\c.png'

[settings]
image_extensions = [".jpg"]
'@
            # PSScriptAnalyzer 假读取：被同 Context 下 It 块继承使用，静态分析不可见
            if ([string]::IsNullOrEmpty($ValidToml)) { throw 'ValidToml 为空' }
        }

        BeforeEach {
            # [System.IO.Path]::GetFullPath 依赖 .NET CurrentDirectory 而非 PowerShell 位置
            $script:OriginalNetDir = [System.Environment]::CurrentDirectory
            $script:OriginalPSLocation = Get-Location
            # 清理可能残留的模块目录 config.toml
            $StrayModuleConfig = Join-Path -Path $ModulePath -ChildPath 'config.toml'
            if (Test-Path -LiteralPath $StrayModuleConfig)
            {
                Remove-Item -LiteralPath $StrayModuleConfig -Force
            }
        }

        AfterEach {
            [System.IO.Directory]::SetCurrentDirectory($script:OriginalNetDir)
            Set-Location $script:OriginalPSLocation
        }

        It '应在未指定 ConfigPath 时从当前目录搜索到 config.toml' {
            Mock Write-LogEntry { }
            Set-Location $TestDrive
            [System.IO.Directory]::SetCurrentDirectory($TestDrive)
            $ConfigFile = Join-Path -Path $TestDrive -ChildPath 'config.toml'
            $ValidToml | Out-File -LiteralPath $ConfigFile -Encoding UTF8 -NoNewline

            $Result = Resolve-Config

            # 1a 使用真实文件 + 真实 ConfigManager，补全字段验证端到端完整性
            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be 'D:\a'
            $Result.ArchiveDir | Should -Be 'D:\b'
            $Result.WarningImagePath | Should -Be 'D:\c.png'
            $Result.ImageExtensions.Count | Should -Be 1
            $Result.ImageExtensions | Should -Be '.jpg'
        }

        It '应在当前目录无 config.toml 时从 $HOME\.finalize_and_archive\ 搜索' {
            Mock Write-LogEntry { }
            # Mock Test-Path：仅 $HOME\.finalize_and_archive\ 路径返回 true
            Mock Test-Path -MockWith {
                if ($LiteralPath -like '*finalize_and_archive*') { return $true }
                return $false
            } -ParameterFilter { $PathType -eq 'Leaf' }
            Mock Get-Content -MockWith { return $ValidToml } -ParameterFilter { $Raw -eq $true }

            $Result = Resolve-Config

            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be 'D:\a'
            $Result.ArchiveDir | Should -Be 'D:\b'
            $Result.WarningImagePath | Should -Be 'D:\c.png'
            $Result.ImageExtensions.Count | Should -Be 1
            $Result.ImageExtensions | Should -Be '.jpg'
        }

        It '应在前两个路径无配置时从模块目录搜索 config.toml' {
            Mock Write-LogEntry { }
            # Mock Test-Path：仅模块目录路径（含 source 但不含 finalize_and_archive）返回 true
            Mock Test-Path -MockWith {
                if ($LiteralPath -like '*source*config.toml*') { return $true }
                return $false
            } -ParameterFilter { $PathType -eq 'Leaf' }
            Mock Get-Content -MockWith { return $ValidToml } -ParameterFilter { $Raw -eq $true }

            $Result = Resolve-Config

            $Result | Should -Not -Be $null
            $Result.ActiveDir | Should -Be 'D:\a'
            $Result.ArchiveDir | Should -Be 'D:\b'
            $Result.WarningImagePath | Should -Be 'D:\c.png'
            $Result.ImageExtensions.Count | Should -Be 1
            $Result.ImageExtensions | Should -Be '.jpg'
        }

        It '应在三个搜索路径都找不到配置文件时返回 $null 并输出 Warning' {
            Mock Write-LogEntry { }
            Mock Test-Path -MockWith { return $false } -ParameterFilter { $PathType -eq 'Leaf' }

            $Result = Resolve-Config

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '未找到配置文件' } -Times 1 -Exactly
        }
    }

    Context 'ConfigPath 空值与空白字符' {
        It '应在 ConfigPath 为空字符串时进入自动搜索逻辑（等同未指定）' {
            Mock Write-LogEntry { }
            Mock Test-Path -MockWith { return $false } -ParameterFilter { $PathType -eq 'Leaf' }

            $Result = Resolve-Config -ConfigPath ''

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Message -eq '未找到配置文件' } -Times 1 -Exactly
        }

        It '应在 ConfigPath 为空白字符时跳过搜索直接尝试加载（加载失败）' {
            Mock Write-LogEntry { }

            $Result = Resolve-Config -ConfigPath '   '

            $Result | Should -Be $null
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Message -like '*配置加载失败*' } -Times 1 -Exactly
        }
    }

}
