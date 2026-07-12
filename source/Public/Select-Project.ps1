function Select-Project {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ActiveDir
    )

    $pattern = '^\d{4}-\d{2}-\d{2}_'

    $projects = @()
    try {
        $entries = Get-ChildItem -Path $ActiveDir -Directory -ErrorAction Stop
        foreach ($entry in $entries) {
            if ($entry.Name -match $pattern) {
                $projects += $entry.FullName
            }
        }
    }
    catch {
        Write-Error "扫描项目目录失败: $_"
        return $null
    }

    if ($projects.Count -eq 0) {
        Write-Warning "未找到项目"
        return $null
    }

    Write-Information "请选择项目:"
    for ($i = 0; $i -lt $projects.Count; $i++) {
        $projectName = [System.IO.Path]::GetFileName($projects[$i])
        Write-Information ("{0}. {1}" -f ($i + 1), $projectName)
    }

    while ($true) {
        try {
            $choice = Read-Host "输入编号"
            $index = [int]$choice - 1

            if ($index -ge 0 -and $index -lt $projects.Count) {
                return $projects[$index]
            }
            Write-Warning "编号超出范围"
        }
        catch {
            Write-Warning "请输入有效数字"
        }
    }
}