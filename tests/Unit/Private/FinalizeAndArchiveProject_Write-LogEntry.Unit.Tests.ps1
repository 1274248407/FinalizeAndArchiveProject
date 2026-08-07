#Requires -Modules Pester

BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\source'
    . (Join-Path -Path $ModulePath -ChildPath 'Private\Write-LogEntry.ps1')
}

Describe 'Write-LogEntry' {
    Context '参数校验' {
        It '应将 Level 标记为 Mandatory 参数' {
            Get-Command Write-LogEntry | Should -HaveParameter Level -Mandatory
        }

        It '应将 Message 标记为 Mandatory 参数' {
            Get-Command Write-LogEntry | Should -HaveParameter Message -Mandatory
        }

        It '应在传入非法 Level 值时抛出参数绑定异常' {
            { Write-LogEntry -Level 'InvalidLevel' -Message 'test' } | Should -Throw
        }

        It '应接受四个合法的 Level 值（Info/Success/Warning/Error）' {
            # Info、Success、Warning 不会抛异常，Error 会抛但已在 ERROR 级别测试中覆盖
            Mock Write-Host { }
            Write-LogEntry -Level Info -Message 'info-msg'
            Write-LogEntry -Level Success -Message 'success-msg'
            Write-LogEntry -Level Warning -Message 'warning-msg'
        }
    }

    Context 'INFO / SUCCESS / WARNING 级别' {
        It '应调用 Write-Host 输出 INFO 级别日志（不抛异常）' {
            Mock Write-Host { }

            { Write-LogEntry -Level Info -Message 'info test' } | Should -Not -Throw

            Should -Invoke Write-Host -Scope It
        }

        It '应调用 Write-Host 输出 SUCCESS 级别日志（不抛异常）' {
            Mock Write-Host { }

            { Write-LogEntry -Level Success -Message 'success test' } | Should -Not -Throw

            Should -Invoke Write-Host -Scope It
        }

        It '应调用 Write-Host 输出 WARNING 级别日志（不抛异常）' {
            Mock Write-Host { }

            { Write-LogEntry -Level Warning -Message 'warning test' } | Should -Not -Throw

            Should -Invoke Write-Host -Scope It
        }
    }

    Context 'ERROR 级别' {
        It '应输出 ERROR 日志后抛出与 Message 一致的终止错误' {
            Mock Write-Host { }

            $ErrorMessage = '配置文件丢失'
            { Write-LogEntry -Level Error -Message $ErrorMessage } | Should -Throw -ExpectedMessage $ErrorMessage

            Should -Invoke Write-Host -Scope It
        }
    }

    Context '日志输出格式完整性' {
        It 'INFO 输出应包含时间戳、INFO、调用者信息、消息四个部分' {
            $CapturedOutput = New-Object -TypeName 'System.Collections.Generic.List[string]'
            Mock Write-Host -MockWith {
                param($Object, [switch]$NoNewline)
                $CapturedOutput.Add([string]$Object)
            }

            Write-LogEntry -Level Info -Message 'format test'

            # 时间戳部分应匹配 yyyy-MM-dd HH:mm:ss.fff 格式
            $Timestamp = $CapturedOutput[0].Trim()
            $Timestamp | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$'

            # 级别部分应包含 "INFO"
            $CapturedOutput[1] | Should -Match 'INFO'

            # 调用者部分应包含 ":" 分隔符（模块:函数:行号）
            $CapturedOutput[2] | Should -Match ':.+:'

            # 消息部分包含实际内容
            $CapturedOutput[3] | Should -Be 'format test'

            # 最后必须有一个换行（无参数的 Write-Host ''）
            $CapturedOutput[-1] | Should -Be ''
        }

        It 'SUCCESS 输出应右对齐级别名称 "SUCCESS"' {
            $CapturedOutput = New-Object -TypeName 'System.Collections.Generic.List[string]'
            Mock Write-Host -MockWith {
                param($Object, [switch]$NoNewline)
                $CapturedOutput.Add([string]$Object)
            }

            Write-LogEntry -Level Success -Message 'done'

            # PadRight(7) → SUCCESS 正好7字符
            $CapturedOutput[1] | Should -Match '\| SUCCESS \|'
        }

        It 'WARNING 输出应右对齐级别名称 "WARNING"' {
            $CapturedOutput = New-Object -TypeName 'System.Collections.Generic.List[string]'
            Mock Write-Host -MockWith {
                param($Object, [switch]$NoNewline)
                $CapturedOutput.Add([string]$Object)
            }

            Write-LogEntry -Level Warning -Message 'caution'

            # PadRight(7) → WARNING 正好7字符
            $CapturedOutput[1] | Should -Match '\| WARNING \|'
        }

        It 'ERROR 输出应右对齐级别名称 "ERROR  " 并带红色背景消息' {
            $CapturedOutput = New-Object -TypeName 'System.Collections.Generic.List[string]'
            $CapturedBgColors = New-Object -TypeName 'System.Collections.Generic.List[string]'
            Mock Write-Host -MockWith {
                param($Object, [switch]$NoNewline, $BackgroundColor)
                $CapturedOutput.Add([string]$Object)
                $CapturedBgColors.Add([string]$BackgroundColor)
            }

            { Write-LogEntry -Level Error -Message 'fatal' } | Should -Throw 'fatal'

            # ERROR 级别消息段（Object='fatal'）应传入 BackgroundColor=Red
            $MessageIndex = $CapturedOutput.IndexOf('fatal')
            $MessageIndex | Should -BeGreaterOrEqual 0
            $CapturedBgColors[$MessageIndex] | Should -Be 'Red'
        }
    }

    Context '调用者信息解析（CallStack 边界）' {
        It '应在脚本块直接调用时将 <ScriptBlock> 映射为 <module>' {
            # 捕获全部 Write-Host 输出对象
            $AllOutputs = New-Object -TypeName 'System.Collections.Generic.List[string]'
            Mock Write-Host -MockWith {
                param($Object, [switch]$NoNewline)
                $AllOutputs.Add([string]$Object)
            }

            # 直接在 It 块（ScriptBlock）中调用，CallStack FunctionName = <ScriptBlock>
            Write-LogEntry -Level Info -Message 'caller test'

            # 调用者信息段是包含 ":" 分隔符且后面带 " - " 的那一次输出
            $CallerSegment = $AllOutputs | Where-Object { $PSItem -match ':.+:.* -' } | Select-Object -First 1

            $CallerSegment | Should -Not -Be $null
            $CallerSegment | Should -Match '<module>'
        }

        It '应通过包装函数正确解析调用者信息格式（模块:函数:行号）' {
            function Test-WrapperFunc
            {
                param([string]$Msg)
                Write-LogEntry -Level Info -Message $Msg
            }

            $AllOutputs = New-Object -TypeName 'System.Collections.Generic.List[string]'
            Mock Write-Host -MockWith {
                param($Object, [switch]$NoNewline)
                $AllOutputs.Add([string]$Object)
            }

            Test-WrapperFunc -Msg 'wrapper test'

            $CallerSegment = $AllOutputs | Where-Object { $PSItem -match ':.+:.* -' } | Select-Object -First 1

            $CallerSegment | Should -Not -Be $null
            # 模块名应解析为 Private（来自 Private\ 子目录）
            $CallerSegment | Should -Match '^Private:'
            # 函数名在 It 块作用域内会以 <module> 形式出现（Pester 执行模型）
            # 调用者格式整体为：模块:函数:行号 - ，行号应为正整数
            $CallerSegment | Should -Match ':.+:\d+ -'
        }
    }
}
