<#
.SYNOPSIS
    发送任务完成提示音
.DESCRIPTION
    使用项目内置的 WAV 音效文件播放任务完成提示音。
    音效文件位于项目根目录的 sounds/ 目录下。
    无需安装任何第三方模块，纯 PowerShell 实现。
.PARAMETER SoundType
    (string) 声音类型：'Success'（成功）、'Warning'（警告）、'Error'（错误）、'Info'（信息）
    默认为 'Success'
.EXAMPLE
    Send-ToastNotification -SoundType Success
    # 播放成功提示音并在控制台显示消息
.EXAMPLE
    Send-ToastNotification -SoundType Error
    # 播放错误提示音并在控制台显示消息
.INPUTS
    [string]
.OUTPUTS
    [void]
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
function Send-ToastNotification
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        # 声音类型
        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$SoundType = 'Success'
    )

    # 音效文件目录（相对于模块根目录）
    $SoundsDir = Join-Path -Path $PSScriptRoot -ChildPath '..\..\sounds'

    # 根据声音类型选择对应的音效文件
    switch ($SoundType)
    {
        'Success'
        {
            $SoundFile = Join-Path -Path $SoundsDir -ChildPath 'success.wav'
            Write-Information '[完成] 任务执行成功！'
        }
        'Warning'
        {
            $SoundFile = Join-Path -Path $SoundsDir -ChildPath 'warning.wav'
            Write-Information '[警告] 任务执行完成，但有警告信息'
        }
        'Error'
        {
            $SoundFile = Join-Path -Path $SoundsDir -ChildPath 'error.wav'
            Write-Information '[错误] 任务执行失败！'
        }
        'Info'
        {
            $SoundFile = Join-Path -Path $SoundsDir -ChildPath 'info.wav'
            Write-Information '[信息] 任务执行完成'
        }
    }

    # 播放音效文件
    if (Test-Path -LiteralPath $SoundFile)
    {
        try
        {
            $Player = [System.Media.SoundPlayer]::new($SoundFile)
            $Player.PlaySync()
            $Player.Dispose()
        }
        catch
        {
            Write-Warning "播放音效失败: $PSItem"
        }
    }
    else
    {
        Write-Warning "音效文件不存在: $SoundFile"
    }
}
