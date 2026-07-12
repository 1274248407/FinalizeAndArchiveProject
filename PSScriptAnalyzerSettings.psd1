@{
    # 启用所有内置严重级别的规则（含 Error, Warning, Information 和 TBD）
    Severity = @('Error', 'Warning', 'Information', 'TBD')

    # 配置具体格式化规则以适配严格的 Allman 风格
    Rules    = @{
        # 强制：开括号（{）必须另起一行，不能跟在语句同行的末尾
        # PSPlaceOpenBrace           = @{
        #     Enable             = $true
        #     OnSameLine         = $true
        #     NewLineAfter       = $true
        #     IgnoreOneLineBlock = $true
        # }

        # 强制：闭括号（}）必须独占一行
        # PSPlaceCloseBrace          = @{
        #     Enable             = $true
        #     NewLineAfter       = $true
        #     IgnoreOneLineBlock = $true
        #     NoEmptyLineBefore  = $false
        # }

        # 强制：缩进一致性（4个空格缩进）
        # PSUseConsistentIndentation = @{
        #     Enable              = $true
        #     Kind                = 'space'
        #     IndentationSize     = 4
        #     PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        # }

        # 强制：严格的空格规范
        # PSUseConsistentWhitespace  = @{
        #     Enable          = $true
        #     CheckOpenBrace  = $true
        #     CheckOpenParen  = $true
        #     CheckOperator   = $true
        #     CheckSeparator  = $true
        #     CheckInnerBrace = $true
        # }
    }
}