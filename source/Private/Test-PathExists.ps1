function Test-PathExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]] $Paths
    )

    foreach ($checkPath in $Paths) {
        if (-not (Test-Path -Path $checkPath)) {
            Write-Error "路径不存在: $checkPath"
            return $false
        }
    }
    return $true
}