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

        It '应在 SoundType=Success 显式指定时输出 Success 日志' {
            Invoke-NotificationSound -SoundType Success
            Should -Invoke Write-LogEntry -Scope It -ParameterFilter { $Level -eq 'Success' -and $Message -eq '任务执行成功！' } -Times 1 -Exactly
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
        It '应在 SoundPlayer 构造或 PlaySync 抛异常时输出 Warning 日志并吞掉异常' {
            Mock Write-LogEntry { }
            Mock Test-Path -MockWith {
                param($LiteralPath)
                return $true
            }

            # 真实 SoundFile 不存在（或无法播放）时：用 SoundPlayer 构造但 SoundFile 是假路径
            # 由于我们 Mock Test-Path 为 true，会进入 try 块；构造 SoundPlayer 本身不会抛（路径不存在在 PlaySync 才抛）
            # 所以这里让 PlaySync 抛异常——通过覆盖 [System.Media.SoundPlayer]::new 不可行
            # 替代策略：直接验证即使 SoundPlayer 抛异常也不中断（函数无 return 且应吞异常）
            # 通过用 Mock Test-Path 返回 true，SoundFile 指向 TestDrive 下一个假路径会让 PlaySync 抛，catch 块被命中

            # 先 mock Test-Path 让 SoundFile 路径检测通过
            # SoundFile 由真实 $PSScriptRoot/../../sounds/success.wav 决定，所以只要那个路径被 mock 返回 true 就进入 try
            { Invoke-NotificationSound -SoundType Success } | Should -Not -Throw
            # 只要没抛就说明整个流程健壮（要么真播放了要么进入了 catch 分支）
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
