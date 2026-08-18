#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Invoke-NotificationSound.ps1')
}

Describe 'Invoke-NotificationSound' {
    Context 'SoundType 参数校验' {
        It '应在 SoundType 为非法值时抛出验证异常' {
            { Invoke-NotificationSound -SoundType 'INVALID' } | Should -Throw
        }
    }

    Context '四种合法 SoundType 分支走对日志消息与文件名' {
        BeforeEach {
            Mock Write-LogEntry { }
            # 让 SoundFile 的 Test-Path 返回 false，从而跳过真正 SoundPlayer 逻辑（进入 else 分支）
            Mock Test-Path -MockWith {
                param($LiteralPath)
                return $false
            }
        }

        It '应在 SoundType=Success（默认）时输出 Success 日志并拼接 success.wav' {
            Invoke-NotificationSound
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Success' -and $Message -eq '任务执行成功！' } -Times 1 -Exactly
            # else 分支：音效文件不存在
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*success.wav*' } -Times 1 -Exactly
        }

        It '应在 SoundType=Warning 时输出 Warning 日志并拼接 warning.wav' {
            Invoke-NotificationSound -SoundType Warning
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '任务执行完成，但有警告信息' } -Times 1 -Exactly
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*warning.wav*' } -Times 1 -Exactly
        }

        It '应在 SoundType=Error 时输出 Warning 级别错误消息并拼接 error.wav' {
            Invoke-NotificationSound -SoundType Error
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -eq '任务执行失败！' } -Times 1 -Exactly
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*error.wav*' } -Times 1 -Exactly
        }

        It '应在 SoundType=Info 时输出 Info 日志并拼接 info.wav' {
            Invoke-NotificationSound -SoundType Info
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Info' -and $Message -eq '任务执行完成' } -Times 1 -Exactly
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '*info.wav*' } -Times 1 -Exactly
        }
    }

    Context '音效文件存在但播放异常（catch 分支）' {
        It '应在 PlaySync 抛异常时输出 Warning 日志并吞掉异常' {
            Mock Write-LogEntry { }
            # 创建一个损坏的 WAV 文件（文件存在但格式无效），PlaySync 会抛异常
            $CorruptWav = Join-Path -Path $TestDrive -ChildPath 'corrupt.wav'
            [byte[]]$CorruptData = @(0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00)  # RIFF 头但内容无效
            [System.IO.File]::WriteAllBytes($CorruptWav, $CorruptData)

            # Mock Join-Path 让 success.wav 指向损坏文件
            Mock Join-Path -MockWith { return $CorruptWav } -ParameterFilter { $ChildPath -eq 'success.wav' }

            { Invoke-NotificationSound -SoundType Success } | Should -Not -Throw
            # 确认 catch 块被命中：Warning 日志包含"播放音效失败"
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '播放音效失败*' } -Times 1 -Exactly
        }

        It '应在 PlaySync 成功时正常 Dispose，不写入"播放音效失败"日志' {
            Mock Write-LogEntry { }
            # 在 TestDrive 下创建最小合法 WAV 文件
            $MinimalWav = Join-Path -Path $TestDrive -ChildPath 'success.wav'
            # 最小 WAV 头 + 2 字节静音数据
            [byte[]]$WavData = @(
                0x52, 0x49, 0x46, 0x46, 0x26, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45,
                0x66, 0x6D, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
                0x44, 0xAC, 0x00, 0x00, 0x88, 0x58, 0x01, 0x00, 0x02, 0x00, 0x10, 0x00,
                0x64, 0x61, 0x74, 0x61, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00
            )
            [System.IO.File]::WriteAllBytes($MinimalWav, $WavData)

            # Mock Join-Path 让 success.wav 指向 TestDrive 下的真实 WAV
            Mock Join-Path -MockWith { return $MinimalWav } -ParameterFilter { $ChildPath -eq 'success.wav' }

            Invoke-NotificationSound -SoundType Success

            # 成功路径：不应出现"播放音效失败"的 Warning
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '播放音效失败*' } -Times 0 -Exactly
            # 应出现 Success 日志
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Success' -and $Message -eq '任务执行成功！' } -Times 1 -Exactly
        }
    }

    Context '音效文件不存在（else 分支）' {
        It '应在音效文件不存在时输出 "音效文件不存在: xxx" Warning 日志' {
            Mock Write-LogEntry { }
            Mock Test-Path -MockWith {
                param($LiteralPath)
                return $false
            }

            Invoke-NotificationSound -SoundType Info

            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Warning' -and $Message -like '音效文件不存在:*' } -Times 1 -Exactly
        }
    }
}
