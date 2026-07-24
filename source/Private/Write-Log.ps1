<#
.SYNOPSIS
    轻量日志函数，模仿 Python loguru 输出格式
.DESCRIPTION
    提供统一的日志输出接口，支持 INFO / SUCCESS / WARNING / ERROR 四个级别。
    输出格式为：时间戳 | 级别 | 调用者信息 - 消息，不同级别使用不同终端颜色。
    ERROR 级别输出日志后会抛出终止错误，保持与 $ErrorActionPreference = 'Stop' 的兼容性。
.PARAMETER Level
    (ValidateSet) 日志级别，可选值为 Info、Success、Warning、Error
.PARAMETER Message
    (string) 日志消息内容
.EXAMPLE
    Write-Log -Level Info -Message "备份创建成功"
.EXAMPLE
    Write-Log -Level Error -Message "配置文件不存在"
.INPUTS
    [string]
.OUTPUTS
    [void]
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Write-Log
{
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string] $Level,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    # 获取调用者信息：跳过 Write-Log 自身（索引1），取实际调用者（索引2）
    $CallerFrame = $null
    $CallStack = Get-PSCallStack
    if ($CallStack.Count -ge 3)
    {
        $CallerFrame = $CallStack[2]
    }
    elseif ($CallStack.Count -ge 2)
    {
        $CallerFrame = $CallStack[1]
    }

    # 解析调用者信息：模块名:函数名:行号
    $CallerInfo = '<unknown>:<unknown>:0'
    if ($null -ne $CallerFrame)
    {
        # 从脚本路径提取模块名（父目录名）
        $ScriptPath = $CallerFrame.ScriptName
        $ModuleName = '<script>'
        if ($ScriptPath)
        {
            $ParentDir = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($ScriptPath))
            if ($ParentDir)
            {
                $ModuleName = $ParentDir
            }
        }

        # 获取函数名（匿名脚本块显示为 <ScriptBlock>）
        $FuncName = $CallerFrame.FunctionName
        if ($FuncName -eq '<ScriptBlock>')
        {
            $FuncName = '<module>'
        }

        # 获取行号
        $LineNumber = $CallerFrame.ScriptLineNumber
        if ($null -eq $LineNumber) { $LineNumber = 0 }

        $CallerInfo = "${ModuleName}:${FuncName}:${LineNumber}"
    }

    # 格式化时间戳（精确到毫秒）
    $Timestamp = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')

    # 级别名称右对齐到7字符（匹配 loguru 的列宽）
    $LevelText = $Level.ToUpper().PadRight(7)

    # 根据级别选择颜色
    $ColorMap = @{
        'Info'    = 'White'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }
    $Color = $ColorMap[$Level]

    # 组装 loguru 风格的日志行
    $LogLine = "${Timestamp} | ${LevelText} | ${CallerInfo} - ${Message}"

    # 输出带颜色的日志
    Write-Host $LogLine -ForegroundColor $Color

    # ERROR 级别抛出终止错误，保持错误传播链
    if ($Level -eq 'Error')
    {
        throw $Message
    }
}
