#Requires -Modules Pester
#Requires -Modules PSToml

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Classes\ConfigManager.ps1')
}

Describe 'ConfigManager' {
    Context 'LoadConfig 静态方法 - 文件不存在' {
        It '应在配置文件不存在时返回 $null' {
            $NotExistFile = Join-Path -Path $TestDrive -ChildPath 'NotExist.toml'

            $Result = [ConfigManager]::LoadConfig($NotExistFile)

            $Result | Should -Be $null
        }

        It '应在传入空字符串时返回 $null' {
            $Result = [ConfigManager]::LoadConfig('')

            $Result | Should -Be $null
        }

        It '应在路径指向目录而非文件时返回 $null' {
            # TestDrive 本身就是一个目录路径
            $Result = [ConfigManager]::LoadConfig($TestDrive)

            $Result | Should -Be $null
        }
    }

    Context 'LoadConfig 静态方法 - 文件存在且合法' {
        It '应正确解析合法的 TOML 配置文件' {
            $ConfigFile = Join-Path -Path $TestDrive -ChildPath 'valid.toml'

            # 写入合法的 TOML 内容（Windows 路径用单引号避免反斜杠转义问题）
            $TomlContent = @'
[paths]
active_dir = 'D:\projects\active'
archive_dir = 'D:\projects\archive'
warning_image = 'D:\projects\warning.png'

[settings]
image_extensions = [".jpg", ".png", ".webp"]
'@
            $TomlContent | Out-File -LiteralPath $ConfigFile -Encoding UTF8 -NoNewline

            $Result = [ConfigManager]::LoadConfig($ConfigFile)

            # 断言1：不应返回 $null
            $Result | Should -Not -Be $null

            # 断言2：应正确解析嵌套结构
            $Result.paths.active_dir | Should -Be 'D:\projects\active'
            $Result.paths.archive_dir | Should -Be 'D:\projects\archive'
            $Result.paths.warning_image | Should -Be 'D:\projects\warning.png'

            # 断言3：应正确解析数组
            $Result.settings.image_extensions.Count | Should -Be 3
            $Result.settings.image_extensions -contains '.jpg' | Should -Be $true
            $Result.settings.image_extensions -contains '.png' | Should -Be $true
            $Result.settings.image_extensions -contains '.webp' | Should -Be $true
        }

        It '应正确处理空 TOML 文件' {
            $ConfigFile = Join-Path -Path $TestDrive -ChildPath 'empty.toml'
            '' | Out-File -LiteralPath $ConfigFile -Encoding UTF8 -NoNewline

            $Result = [ConfigManager]::LoadConfig($ConfigFile)

            # 空文件会导致 Get-Content 返回 $null，ConvertFrom-Toml 拒绝 $null 输入，
            # catch 块捕获异常并返回 $null（空文件不是有效配置）
            $Result | Should -Be $null
        }
    }

    Context 'LoadConfig 静态方法 - 文件存在但非法' {
        It '应在 TOML 格式错误时返回 $null' {
            $ConfigFile = Join-Path -Path $TestDrive -ChildPath 'invalid.toml'

            # 写入非法的 TOML 内容（缺少引号、括号不匹配等）
            $InvalidContent = @'
[paths
active_dir = D:\projects\active
this is not valid toml =
'@
            $InvalidContent | Out-File -LiteralPath $ConfigFile -Encoding UTF8 -NoNewline

            $Result = [ConfigManager]::LoadConfig($ConfigFile)

            # 断言：TOML 解析失败时应返回 $null（由 catch 块捕获）
            $Result | Should -Be $null
        }
    }

    Context 'LoadConfig 静态方法 - 特殊路径字符' {
        It '应正确处理路径中的方括号特殊字符' {
            # 路径包含 [test] 方括号，验证 Get-Content 是否使用了 -LiteralPath
            $ConfigFile = Join-Path -Path $TestDrive -ChildPath '2026-07-24_[test].toml'

            $TomlContent = @'
[paths]
active_dir = 'D:\active'
'@
            # 使用 .NET 方法写入文件，避免 PowerShell 通配符解释
            [System.IO.File]::WriteAllText($ConfigFile, $TomlContent)

            $Result = [ConfigManager]::LoadConfig($ConfigFile)

            # 断言：方括号路径应能正确读取和解析
            $Result | Should -Not -Be $null
            $Result.paths.active_dir | Should -Be 'D:\active'
        }
    }
}
