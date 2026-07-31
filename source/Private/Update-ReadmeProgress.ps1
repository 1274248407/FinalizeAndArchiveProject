<#
.SYNOPSIS
    更新 README 中的进度标记
.DESCRIPTION
    将 README.md 中的所有待办项标记为已完成，并更新嵌字进度。
    失败不影响主流程。
.PARAMETER ProjectDir
    (string) 项目目录路径
.PARAMETER TotalPages
    (int) 总页数
.EXAMPLE
    Update-ReadmeProgress -ProjectDir $ProjectDir -TotalPages 42
.INPUTS
    [string], [int]
.OUTPUTS
    [void]
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Update-ReadmeProgress
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ProjectDir,

        [Parameter(Mandatory = $true)]
        [int] $TotalPages
    )

    $ReadmePath = Join-Path -Path $ProjectDir -ChildPath 'README.md'
    if (-not (Test-Path -LiteralPath $ReadmePath -PathType Leaf))
    {
        return
    }

    try
    {
        $Content = Get-Content -LiteralPath $ReadmePath -Raw -Encoding UTF8

        $Items = @(
            '文件整理与分离',
            'OCR 处理与校对',
            'Inpainting 处理与修正',
            '文本翻译',
            '最终质量检查'
        )

        foreach ($Item in $Items)
        {
            $Content = $Content -replace '- \[ \] ' + [regex]::Escape($Item), '- [X] ' + $Item
        }

        $Content = $Content -replace '- \[\[ Xx\]\?\] 嵌字 \(完成至页 .*?\)', "- [X] 嵌字 (完成至页 $TotalPages)"

        if ($PSCmdlet.ShouldProcess($ReadmePath, '更新 README 进度标记'))
        {
            Set-Content -LiteralPath $ReadmePath -Value $Content -Encoding UTF8 -NoNewline
            Write-LogEntry -Level Success -Message 'README更新完成'
        }
    }
    catch
    {
        Write-LogEntry -Level Warning -Message "README更新失败: $PSItem"
    }
}
